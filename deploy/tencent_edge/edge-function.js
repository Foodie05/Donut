const EDGE_PROXY_HEADER = 'x-donut-edge-proxy';
const EDGE_REQUEST_ID_HEADER = 'x-donut-edge-request-id';
const EO_TIMEOUT_SETTINGS = {
  connectTimeout: 60000,
  readTimeout: 120000,
  writeTimeout: 60000,
};

const config = {
  backendOrigin: readConfig('DONUT_BACKEND_ORIGIN', 'https://backend.yunwu.ai'),
  upstreamBaseUrl: readConfig(
    'DONUT_UPSTREAM_BASE_URL',
    'https://api.openai.com/v1/',
  ),
  upstreamApiKey: readConfig('DONUT_UPSTREAM_API_KEY', ''),
  apiTokenSecret: readConfig('DONUT_API_TOKEN_SIGNING_SECRET', ''),
  apiTokenIssuer: readConfig('DONUT_API_TOKEN_ISSUER', 'donut-backend'),
  apiTokenAudience: readConfig('DONUT_API_TOKEN_AUDIENCE', 'donut-edge'),
  imageLimit: parseInt(readConfig('DONUT_API_TOKEN_IMAGE_LIMIT', '5'), 10) || 5,
};

async function handleRequest(request) {
  const traceId = createRequestId();
  const startedAt = Date.now();
  try {
    const url = new URL(request.url);
    logInfo('request.start', {
      traceId,
      method: request.method,
      url: request.url,
      pathname: url.pathname,
    });

    if (isAiPath(url.pathname)) {
      return handleAiRequest(request, url, traceId);
    }

    return proxyToBackend(request, url, traceId);
  } catch (error) {
    logError('request.crash', {
      traceId,
      elapsedMs: Date.now() - startedAt,
      error: safeErrorMessage(error),
    });
    return jsonError(
      500,
      `Edge function crashed: ${safeErrorMessage(error)}`,
      'edge_runtime_error',
    );
  }
}

async function handleAiRequest(request, url, traceId) {
  if (!config.upstreamApiKey || !config.apiTokenSecret) {
    return jsonError(
      500,
      'The edge gateway is missing required secret configuration.',
      'edge_not_configured',
    );
  }

  const authToken = extractBearerToken(request.headers.get('authorization'));
  if (!authToken) {
    return jsonError(401, 'Invalid API key provided.', 'invalid_api_key');
  }

  const verifiedToken = await verifyApiToken(authToken);
  if (!verifiedToken.ok) {
    return jsonError(
      401,
      'Your API token expired. Please refresh your session.',
      'token_refresh_required',
    );
  }

  logInfo('ai.request.accepted', {
    traceId,
    pathname: url.pathname,
    method: request.method,
    user: verifiedToken.payload.sub,
  });

  if (url.pathname === '/v1/chat/completions') {
    return handleMeteredJsonAiRequest(
      request,
      url,
      authToken,
      verifiedToken.payload,
      traceId,
      'chat_completions',
    );
  }

  if (url.pathname === '/v1/responses') {
    return handleMeteredJsonAiRequest(
      request,
      url,
      authToken,
      verifiedToken.payload,
      traceId,
      'responses',
    );
  }

  return proxyAiRequest(request, url, {
    bodyText: undefined,
    tokenPayload: verifiedToken.payload,
    authToken,
    chargeUsage: false,
    usageAmount: 0,
    imageCount: 0,
    pdfCount: 0,
    traceId,
  });
}

async function handleMeteredJsonAiRequest(
  request,
  url,
  authToken,
  tokenPayload,
  traceId,
  mode,
) {
  if (request.method !== 'POST') {
    return jsonError(405, 'Method not allowed.', 'method_not_allowed');
  }

  let bodyText = '';
  let payload;
  try {
    bodyText = await request.text();
    payload = JSON.parse(bodyText);
  } catch (error) {
    return jsonError(400, 'The request body must be valid JSON.', 'invalid_json');
  }

  const mediaCount = mode === 'responses'
    ? countResponsesMedia(payload)
    : countChatMedia(payload);
  const imageCount = mediaCount.imageCount;
  const pdfCount = mediaCount.pdfCount;
  const totalMediaCount = imageCount + pdfCount;
  const imageLimit = tokenPayload.img_limit || config.imageLimit;
  if (totalMediaCount > imageLimit) {
    return jsonError(
      400,
      `At most ${imageLimit} media inputs (images + pdf files) are allowed per request.`,
      'image_limit_exceeded',
    );
  }

  const usageAmount = Math.max(1, totalMediaCount);
  const quotaRemaining = Number(tokenPayload.quota_remaining || 0);
  logInfo(`ai.${mode}.parsed`, {
    traceId,
    model: payload && payload.model,
    imageCount,
    pdfCount,
    totalMediaCount,
    usageAmount,
    quotaRemaining,
  });
  if (!(quotaRemaining > usageAmount && quotaRemaining >= 5)) {
    return jsonError(
      429,
      'Daily quota exceeded for this account.',
      'daily_quota_exceeded',
    );
  }

  return proxyAiRequest(request, url, {
    bodyText,
    tokenPayload,
    authToken,
    chargeUsage: true,
    usageAmount,
    imageCount,
    pdfCount,
    traceId,
  });
}

async function proxyAiRequest(request, url, options) {
  const upstreamUrl = buildUpstreamUrl(url.pathname, url.search);
  const headers = new Headers(request.headers);
  headers.set('authorization', `Bearer ${config.upstreamApiKey}`);
  headers.set(EDGE_PROXY_HEADER, '1');
  headers.delete('host');
  const upstreamBody =
    request.method === 'GET' || request.method === 'HEAD'
      ? undefined
      : options.bodyText !== undefined
        ? options.bodyText
        : request.body;

  let upstreamResponse;
  try {
    const startedAt = Date.now();
    logInfo('upstream.fetch.start', {
      traceId: options.traceId,
      method: request.method,
      upstreamUrl,
      imageCount: options.imageCount,
      pdfCount: options.pdfCount || 0,
      chargeUsage: options.chargeUsage,
    });
    upstreamResponse = await fetch(upstreamUrl, {
      method: request.method,
      headers,
      body: upstreamBody,
      eo: {
        timeoutSetting: EO_TIMEOUT_SETTINGS,
      },
    });
    logInfo('upstream.fetch.finish', {
      traceId: options.traceId,
      upstreamUrl,
      status: upstreamResponse.status,
      elapsedMs: Date.now() - startedAt,
    });
  } catch (error) {
    logError('upstream.fetch.error', {
      traceId: options.traceId,
      upstreamUrl,
      error: safeErrorMessage(error),
      imageCount: options.imageCount,
      pdfCount: options.pdfCount || 0,
    });
    return jsonError(
      502,
      `Failed to reach upstream model provider: ${safeErrorMessage(error)}`,
      'upstream_fetch_failed',
    );
  }

  if (
    options.chargeUsage &&
    upstreamResponse.status >= 200 &&
    upstreamResponse.status < 300
  ) {
    const requestId = createRequestId();
    logInfo('usage.report.queue', {
      traceId: options.traceId,
      requestId,
      amount: options.usageAmount,
      imageCount: options.imageCount,
      pdfCount: options.pdfCount || 0,
    });
    reportUsage({
      authToken: options.authToken,
      requestId,
      amount: options.usageAmount,
      model: safeModelName(options.bodyText),
      usageMode:
        request.headers.get('x-donut-usage-mode') || request.headers.get('X-Donut-Usage-Mode'),
      imageCount: options.imageCount,
      pdfCount: options.pdfCount || 0,
      traceId: options.traceId,
    }).catch((error) => {
      logError('usage.report.throw', {
        traceId: options.traceId,
        requestId,
        error: safeErrorMessage(error),
      });
    });
  }

  return rebuildResponse(upstreamResponse, {
    'x-edgefunctions-header': 'Handled by Donut edge gateway',
    'access-control-allow-methods': request.method,
  });
}

async function proxyToBackend(request, url, traceId) {
  const backendUrl = new URL(url.pathname + url.search, ensureTrailingSlash(config.backendOrigin));
  const headers = new Headers(request.headers);
  headers.set(EDGE_PROXY_HEADER, '1');
  headers.set(EDGE_REQUEST_ID_HEADER, createRequestId());
  headers.delete('host');

  let response;
  try {
    const startedAt = Date.now();
    logInfo('backend.fetch.start', {
      traceId,
      method: request.method,
      backendUrl: backendUrl.toString(),
    });
    response = await fetch(backendUrl.toString(), {
      method: request.method,
      headers,
      body:
        request.method === 'GET' || request.method === 'HEAD'
          ? undefined
          : request.body,
      redirect: 'manual',
      eo: {
        timeoutSetting: EO_TIMEOUT_SETTINGS,
      },
    });
    logInfo('backend.fetch.finish', {
      traceId,
      backendUrl: backendUrl.toString(),
      status: response.status,
      elapsedMs: Date.now() - startedAt,
    });
  } catch (error) {
    logError('backend.fetch.error', {
      traceId,
      backendUrl: backendUrl.toString(),
      error: safeErrorMessage(error),
    });
    return jsonError(
      502,
      `Failed to reach backend origin: ${safeErrorMessage(error)}`,
      'backend_fetch_failed',
    );
  }

  return rebuildResponse(response, {
    'x-edgefunctions-header': 'Proxied by Donut edge gateway',
    'access-control-allow-methods': request.method,
  });
}

async function reportUsage(report) {
  const startedAt = Date.now();
  logInfo('usage.report.start', {
    traceId: report.traceId,
    requestId: report.requestId,
    amount: report.amount,
    imageCount: report.imageCount,
    pdfCount: report.pdfCount || 0,
  });
  const response = await fetch(
    new URL('/edge/usage/report', ensureTrailingSlash(config.backendOrigin)).toString(),
    {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${report.authToken}`,
        [EDGE_PROXY_HEADER]: '1',
      },
      body: JSON.stringify({
        requestId: report.requestId,
        amount: report.amount,
        model: report.model,
        usageMode: report.usageMode,
        imageCount: report.imageCount,
        pdfCount: report.pdfCount || 0,
      }),
      eo: {
        timeoutSetting: EO_TIMEOUT_SETTINGS,
      },
    },
  );

  if (response.status >= 400) {
    const text = await response.text();
    logWarn('usage.report.failed', {
      traceId: report.traceId,
      requestId: report.requestId,
      status: response.status,
      elapsedMs: Date.now() - startedAt,
      bodyPreview: text.slice(0, 500),
    });
    return;
  }

  logInfo('usage.report.finish', {
    traceId: report.traceId,
    requestId: report.requestId,
    status: response.status,
    elapsedMs: Date.now() - startedAt,
  });
}

function rebuildResponse(response, extraHeaders) {
  const headers = new Headers(response.headers);
  Object.keys(extraHeaders).forEach((key) => {
    headers.set(key, extraHeaders[key]);
  });
  headers.delete('x-cos-request-id');
  headers.delete('x-cos-hash-crc64ecma');

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

function isAiPath(pathname) {
  return (
    pathname === '/v1/chat/completions' ||
    pathname === '/v1/responses' ||
    pathname === '/v1/files' ||
    pathname.indexOf('/v1/files/') === 0 ||
    pathname === '/v1/models' ||
    pathname.indexOf('/v1/models/') === 0
  );
}

function buildUpstreamUrl(pathname, search) {
  const base = ensureTrailingSlash(config.upstreamBaseUrl);
  const upstreamPath = pathname.replace(/^\/v1\//, '');
  return new URL(upstreamPath + search, base).toString();
}

function ensureTrailingSlash(value) {
  return value.endsWith('/') ? value : `${value}/`;
}

function extractBearerToken(headerValue) {
  if (!headerValue) return '';
  const parts = headerValue.trim().split(/\s+/);
  if (parts.length !== 2 || parts[0].toLowerCase() !== 'bearer') return '';
  return parts[1];
}

function countImages(payload) {
  return countChatMedia(payload).imageCount;
}

function countChatMedia(payload) {
  if (!payload || !Array.isArray(payload.messages)) {
    return { imageCount: 0, pdfCount: 0 };
  }
  let imageCount = 0;
  let pdfCount = 0;
  payload.messages.forEach((message) => {
    const content = message && message.content;
    const counted = countContentArrayMedia(content);
    imageCount += counted.imageCount;
    pdfCount += counted.pdfCount;
  });
  return { imageCount, pdfCount };
}

function countResponsesMedia(payload) {
  if (!payload || !Array.isArray(payload.input)) {
    return { imageCount: 0, pdfCount: 0 };
  }
  let imageCount = 0;
  let pdfCount = 0;
  payload.input.forEach((item) => {
    if (!item) return;
    const content = item.content;
    const counted = countContentArrayMedia(content);
    imageCount += counted.imageCount;
    pdfCount += counted.pdfCount;
  });
  return { imageCount, pdfCount };
}

function countContentArrayMedia(content) {
  if (!Array.isArray(content)) {
    return { imageCount: 0, pdfCount: 0 };
  }
  let imageCount = 0;
  let pdfCount = 0;
  content.forEach((item) => {
    if (!item || typeof item !== 'object') return;
    const type = item.type;

    if (type === 'image_url' || type === 'input_image') {
      imageCount += 1;
      return;
    }

    if (type === 'document') {
      const mimeType = String(item.mime_type || item.mimeType || '').toLowerCase();
      if (isPdfMimeType(mimeType)) {
        pdfCount += 1;
      }
      return;
    }

    if (type === 'file' || type === 'input_file') {
      const mimeType = String(
        item.mime_type ||
          item.mimeType ||
          (item.file && item.file.mime_type) ||
          (item.file && item.file.mimeType) ||
          '',
      ).toLowerCase();
      const fileName = String(
        item.filename ||
          item.file_name ||
          (item.file && item.file.filename) ||
          (item.file && item.file.file_name) ||
          '',
      ).toLowerCase();
      const fileData = String(item.file_data || item.fileData || '').toLowerCase();
      if (
        isPdfMimeType(mimeType) ||
        fileName.endsWith('.pdf') ||
        fileData.indexOf('data:application/pdf') === 0
      ) {
        pdfCount += 1;
      }
    }
  });
  return { imageCount, pdfCount };
}

function isPdfMimeType(mimeType) {
  return mimeType === 'application/pdf';
}

function safeModelName(bodyText) {
  if (!bodyText) return null;
  try {
    const payload = JSON.parse(bodyText);
    return payload.model || null;
  } catch (error) {
    return null;
  }
}

function jsonError(status, message, code) {
  return new Response(
    JSON.stringify({
      error: {
        message,
        type: 'invalid_request_error',
        param: null,
        code,
      },
    }),
    {
      status,
      headers: {
        'content-type': 'application/json',
        'x-edgefunctions-header': 'Handled by Donut edge gateway',
      },
    },
  );
}

function safeErrorMessage(error) {
  if (!error) return 'unknown error';
  if (typeof error === 'string') return error;
  if (error && error.message) return String(error.message);
  try {
    return JSON.stringify(error);
  } catch (_) {
    return String(error);
  }
}

function logInfo(event, data) {
  console.info(JSON.stringify(buildLogRecord(event, data)));
}

function logWarn(event, data) {
  console.warn(JSON.stringify(buildLogRecord(event, data)));
}

function logError(event, data) {
  console.error(JSON.stringify(buildLogRecord(event, data)));
}

function buildLogRecord(event, data) {
  return {
    ts: new Date().toISOString(),
    event,
    ...data,
  };
}

function readConfig(key, fallbackValue) {
  const globalObject =
    typeof globalThis !== 'undefined' && globalThis ? globalThis : {};
  const envObject =
    typeof env !== 'undefined' && env
      ? env
      : globalObject.env;
  if (envObject && envObject[key] !== undefined && envObject[key] !== null) {
    return String(envObject[key]);
  }
  const processObject = globalObject.process;
  if (processObject && processObject.env && processObject.env[key]) {
    return processObject.env[key];
  }
  if (globalObject[key]) {
    return globalObject[key];
  }
  return fallbackValue;
}

function createRequestId() {
  return `edge_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`;
}

async function verifyApiToken(token) {
  const parts = token.split('.');
  if (parts.length !== 3) {
    return { ok: false };
  }

  const signingInput = `${parts[0]}.${parts[1]}`;
  const expectedSignature = await signHmac(signingInput, config.apiTokenSecret);
  if (expectedSignature !== parts[2]) {
    return { ok: false };
  }

  let payload;
  try {
    payload = JSON.parse(base64UrlDecode(parts[1]));
  } catch (error) {
    return { ok: false };
  }

  const nowSeconds = Math.floor(Date.now() / 1000);
  if (payload.iss !== config.apiTokenIssuer) {
    return { ok: false };
  }
  if (payload.aud !== config.apiTokenAudience) {
    return { ok: false };
  }
  if (!payload.exp || nowSeconds >= payload.exp) {
    return { ok: false };
  }
  if (!payload.sid || !payload.sub || !payload.email) {
    return { ok: false };
  }

  return { ok: true, payload };
}

async function signHmac(input, secret) {
  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'HMAC',
    cryptoKey,
    new TextEncoder().encode(input),
  );
  return base64UrlEncode(new Uint8Array(signature));
}

function base64UrlDecode(value) {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const padding = normalized.length % 4 === 0 ? '' : '='.repeat(4 - (normalized.length % 4));
  const decoded = atob(normalized + padding);
  const bytes = new Uint8Array(decoded.length);
  for (let i = 0; i < decoded.length; i += 1) {
    bytes[i] = decoded.charCodeAt(i);
  }
  return new TextDecoder().decode(bytes);
}

function base64UrlEncode(bytes) {
  let binary = '';
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

export default {
  async fetch(request) {
    return handleRequest(request);
  },
};
