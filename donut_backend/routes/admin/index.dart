import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:donut_backend/src/config/app_config.dart';

Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.get) {
    return Response(
      statusCode: HttpStatus.methodNotAllowed,
      headers: {'allow': 'GET'},
    );
  }

  final config = AppConfig.fromEnvironment(Platform.environment);
  return Response(
    headers: {
      HttpHeaders.contentTypeHeader: 'text/html; charset=utf-8',
    },
    body: _adminHtml(config.adminEnabled),
  );
}

String _adminHtml(bool adminEnabled) {
  final statusLabel = adminEnabled ? '已启用' : '未启用';
  final statusColor = adminEnabled ? '#1d7a43' : '#a3333d';
  return '''
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Donut 管理后台</title>
  <style>
    :root {
      --bg: #f5efe4;
      --card: rgba(255,253,248,0.92);
      --ink: #231f1b;
      --muted: #6c6156;
      --line: #dfd3c3;
      --accent: #8c3b3b;
      --accent-soft: #efe2d6;
      --accent-2: #294d40;
      --ok: #1d7a43;
      --danger: #a3333d;
      --tag: #e6edf9;
      --tag-ink: #395277;
    }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: "SF Pro Text", "PingFang SC", sans-serif; background: linear-gradient(180deg, #efe5d5, var(--bg)); color: var(--ink); }
    .shell { width: min(1120px, calc(100vw - 32px)); margin: 32px auto; }
    .hero, .card { background: var(--card); backdrop-filter: blur(14px); border: 1px solid rgba(223,211,195,0.8); border-radius: 24px; box-shadow: 0 18px 50px rgba(35,31,27,0.10); }
    .hero { padding: 28px; margin-bottom: 20px; display: grid; gap: 14px; }
    .card { padding: 24px; margin-bottom: 20px; }
    h1, h2, h3 { margin: 0; }
    h1 { font-family: Georgia, "Noto Serif SC", serif; font-size: 36px; }
    h2 { font-size: 20px; margin-bottom: 14px; }
    h3 { font-size: 16px; margin-bottom: 10px; }
    p { margin: 0; color: var(--muted); line-height: 1.6; }
    .status { display: inline-flex; align-items: center; gap: 10px; padding: 10px 14px; border-radius: 999px; background: rgba(255,255,255,0.75); width: fit-content; }
    .status-dot { width: 10px; height: 10px; border-radius: 999px; background: ${statusColor}; }
    .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; }
    .field { display: grid; gap: 8px; }
    .field.full { grid-column: 1 / -1; }
    label { font-weight: 600; }
    input, textarea { width: 100%; border: 1px solid var(--line); border-radius: 14px; padding: 12px 14px; background: #fffefb; color: var(--ink); font: inherit; }
    textarea { min-height: 120px; resize: vertical; }
    .row { display: flex; gap: 12px; flex-wrap: wrap; }
    button { border: 0; border-radius: 14px; padding: 12px 18px; font: inherit; font-weight: 700; cursor: pointer; }
    button.primary { background: var(--accent); color: white; }
    button.secondary { background: #ece1d4; color: var(--ink); }
    button.danger { background: var(--danger); color: white; }
    button:disabled { opacity: 0.55; cursor: not-allowed; }
    .hidden { display: none !important; }
    .message { margin-top: 12px; min-height: 24px; color: var(--muted); }
    .meta { display: grid; gap: 6px; color: var(--muted); font-size: 14px; }
    .section-title { margin: 28px 0 12px; }
    .model-shell { display: grid; gap: 12px; margin-top: 16px; }
    .model-empty { border: 1px dashed var(--line); border-radius: 18px; padding: 16px; color: var(--muted); background: #fffaf3; }
    .model-item { border: 1px solid var(--line); border-radius: 18px; padding: 14px 16px; background: #fffaf3; display: flex; align-items: center; justify-content: space-between; gap: 12px; }
    .model-main { display: flex; align-items: center; gap: 12px; min-width: 0; }
    .model-name { font-weight: 700; word-break: break-all; }
    .model-actions { display: flex; align-items: center; gap: 14px; flex-wrap: wrap; justify-content: flex-end; }
    .inline-check { display: inline-flex; align-items: center; gap: 8px; color: var(--muted); }
    .inline-check input { width: auto; margin: 0; }
    .tag { display: inline-flex; align-items: center; border-radius: 999px; padding: 3px 10px; background: var(--tag); color: var(--tag-ink); font-size: 12px; font-weight: 700; }
    .tag-list { display: flex; gap: 10px; flex-wrap: wrap; }
    .tag-chip { display: inline-flex; align-items: center; gap: 8px; border-radius: 999px; padding: 8px 12px; background: var(--tag); color: var(--tag-ink); font-size: 13px; font-weight: 700; }
    .tag-chip button { padding: 0; width: 18px; height: 18px; border-radius: 999px; background: transparent; color: inherit; font-size: 14px; line-height: 1; }
    .summary-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; margin-top: 16px; }
    .summary-card { border: 1px solid var(--line); border-radius: 18px; padding: 16px; background: #fffaf3; display: grid; gap: 12px; }
    .summary-card h4 { margin: 0; font-size: 15px; }
    .summary-meta { font-size: 13px; color: var(--muted); }
    .modal-backdrop { position: fixed; inset: 0; background: rgba(35,31,27,0.38); display: flex; align-items: center; justify-content: center; padding: 24px; z-index: 1000; }
    .modal { width: min(980px, 96vw); max-height: min(88vh, 980px); overflow: hidden; display: grid; grid-template-rows: auto auto 1fr auto; }
    .modal-head { display: flex; justify-content: space-between; align-items: center; gap: 16px; margin-bottom: 12px; }
    .modal-body { overflow: auto; padding-right: 4px; }
    .modal-toolbar { display: grid; gap: 12px; margin-bottom: 16px; }
    .search-input { width: 100%; }
    .manage-note { font-size: 13px; color: var(--muted); }
    .hint { font-size: 13px; color: var(--muted); }
    @media (max-width: 900px) {
      .grid { grid-template-columns: 1fr; }
      .summary-grid { grid-template-columns: 1fr; }
      .model-item { align-items: flex-start; flex-direction: column; }
      .model-actions { justify-content: flex-start; }
    }
  </style>
</head>
<body>
  <div class="shell">
    <section class="hero">
      <h1>Donut 管理后台</h1>
      <p>用于管理模型、上游网关和 OIDC 配置。登录使用环境变量、<code>.env</code> 或运行时配置文件中的 <code>DONUT_ADMIN_SECRET</code>。</p>
      <div class="status"><span class="status-dot"></span><strong>管理后台 ${statusLabel}</strong></div>
    </section>

    <section id="login-card" class="card">
      <h2>管理员登录</h2>
      <p>请输入 <code>DONUT_ADMIN_SECRET</code> 对应的管理员密钥。</p>
      <div class="grid" style="margin-top:16px;">
        <div class="field full">
          <label for="admin-secret">管理员密钥</label>
          <input id="admin-secret" type="password" autocomplete="current-password" />
        </div>
      </div>
      <div class="row" style="margin-top:16px;">
        <button id="login-button" class="primary">登录</button>
      </div>
      <div id="login-message" class="message"></div>
    </section>

    <section id="app-card" class="card hidden">
      <div class="row" style="justify-content: space-between; align-items: center;">
        <div>
          <h2>运行时配置</h2>
          <p>保存后会写入运行时覆盖文件，并立即对后续请求生效。</p>
        </div>
        <button id="logout-button" class="secondary">退出登录</button>
      </div>

      <div class="meta" style="margin:18px 0 24px;">
        <div>运行时覆盖文件：<code id="config-path">-</code></div>
        <div>Dotenv 文件：<code id="dotenv-path">-</code></div>
      </div>

      <form id="config-form">
        <h2>网关与模型</h2>
        <div class="grid">
          <div class="field">
            <label for="upstream-base-url">上游 Base URL</label>
            <input id="upstream-base-url" placeholder="https://api.openai.com/v1" />
          </div>
          <div class="field">
            <label for="client-api-key">客户端 API Key</label>
            <input id="client-api-key" />
          </div>
          <div class="field full">
            <label for="upstream-api-key">上游 API Key</label>
            <input id="upstream-api-key" type="password" />
          </div>
          <div class="field full">
            <label for="api-token-signing-secret">JWT 签名密钥</label>
            <input id="api-token-signing-secret" type="password" placeholder="后端与边缘函数必须一致" />
          </div>
          <div class="field">
            <label for="api-token-issuer">JWT Issuer</label>
            <input id="api-token-issuer" placeholder="donut-backend" />
          </div>
          <div class="field">
            <label for="api-token-audience">JWT Audience</label>
            <input id="api-token-audience" placeholder="donut-edge" />
          </div>
          <div class="field">
            <label for="api-token-image-limit">JWT 图片上限</label>
            <input id="api-token-image-limit" type="number" min="1" step="1" />
          </div>
          <div class="field">
            <label for="public-base-url">公网 Base URL</label>
            <input id="public-base-url" placeholder="http://127.0.0.1:8085" />
          </div>
          <div class="field">
            <label for="daily-page-limit">每日额度（页）</label>
            <input id="daily-page-limit" type="number" min="1" step="0.5" />
          </div>
        </div>

        <div class="row" style="margin-top:20px;">
          <button type="button" id="probe-models-button" class="secondary">测试连接并获取模型</button>
        </div>
        <div id="probe-message" class="message"></div>

        <div class="section-title">
          <h3>模型发布设置</h3>
          <p>先测试连接并拉取模型列表，再在二级页面中搜索、勾选要提供给用户的模型，并选择推荐模型与默认模型。保存后会立即对客户端配置生效。</p>
        </div>
        <div class="row">
          <button type="button" id="manage-models-button" class="secondary">管理模型列表</button>
        </div>
        <div id="model-list" class="summary-grid"></div>

        <h2 style="margin-top:28px;">OIDC</h2>
        <div class="grid">
          <div class="field">
            <label for="auth-issuer">OIDC Issuer</label>
            <input id="auth-issuer" />
          </div>
          <div class="field">
            <label for="auth-client-id">OIDC Client ID</label>
            <input id="auth-client-id" />
          </div>
          <div class="field full">
            <label for="auth-client-secret">OIDC Client Secret</label>
            <input id="auth-client-secret" type="password" />
          </div>
          <div class="field full">
            <label for="auth-scopes">OIDC Scopes</label>
            <input id="auth-scopes" />
          </div>
        </div>

        <h2 style="margin-top:28px;">临时文件存储</h2>
        <div class="grid">
          <div class="field">
            <label for="storage-endpoint">存储 API Endpoint</label>
            <input id="storage-endpoint" placeholder="https://s3.example.com" />
          </div>
          <div class="field">
            <label for="storage-public-base-url">存储访问基址</label>
            <input id="storage-public-base-url" placeholder="https://cdn.example.com/donut-temp/" />
          </div>
          <div class="field">
            <label for="storage-region">存储 Region</label>
            <input id="storage-region" placeholder="auto" />
          </div>
          <div class="field">
            <label for="storage-bucket">Bucket 名称</label>
            <input id="storage-bucket" />
          </div>
          <div class="field">
            <label for="storage-access-key">Access Key</label>
            <input id="storage-access-key" />
          </div>
          <div class="field">
            <label for="storage-secret-key">Secret Key</label>
            <input id="storage-secret-key" type="password" />
          </div>
          <div class="field full">
            <label for="storage-path-prefix">存储路径前缀</label>
            <input id="storage-path-prefix" placeholder="donut-temp/reader" />
          </div>
        </div>
        <div class="row" style="margin-top:20px;">
          <button type="button" id="test-storage-button" class="secondary">测试存储桶连接</button>
        </div>
        <div id="storage-message" class="message"></div>

        <h2 style="margin-top:28px;">Rosemary 更新（公开字段）</h2>
        <div class="grid">
          <div class="field">
            <label for="rosemary-enabled">启用 Rosemary 检查</label>
            <select id="rosemary-enabled">
              <option value="false">关闭</option>
              <option value="true">开启</option>
            </select>
          </div>
          <div class="field">
            <label for="rosemary-res-version">资源版本号（resVersion）</label>
            <input id="rosemary-res-version" type="number" min="0" step="1" />
          </div>
          <div class="field full">
            <label for="rosemary-api-base-url">Rosemary API Base URL</label>
            <input id="rosemary-api-base-url" placeholder="https://rosemary.example.com" />
          </div>
          <div class="field full">
            <label for="rosemary-app-name">Rosemary App Name / Request ID</label>
            <input id="rosemary-app-name" placeholder="public app id (no password)" />
          </div>
        </div>

        <div class="row" style="margin-top:24px;">
          <button type="submit" class="primary">保存配置</button>
          <button type="button" id="reload-button" class="secondary">重新加载</button>
        </div>
      </form>
      <div id="config-message" class="message"></div>
    </section>
  </div>

  <div id="model-modal-backdrop" class="modal-backdrop hidden">
    <section class="card modal">
      <div class="modal-head">
        <div>
          <h2>管理模型列表</h2>
          <p>支持搜索、勾选提供给用户的模型，并设置推荐模型与默认模型。</p>
        </div>
        <button type="button" id="close-models-button" class="secondary">关闭</button>
      </div>
      <div class="modal-toolbar">
        <input id="model-search-input" class="search-input" placeholder="搜索模型名称" />
        <div class="manage-note">当前修改会自动保存，并立即同步给客户端配置。</div>
      </div>
      <div id="model-manage-list" class="modal-body model-shell"></div>
      <div class="row" style="margin-top:16px; justify-content: flex-end;">
        <button type="button" id="done-models-button" class="primary">完成</button>
      </div>
    </section>
  </div>

  <script>
    const TOKEN_KEY = 'donut_admin_token';
    const loginCard = document.getElementById('login-card');
    const appCard = document.getElementById('app-card');
    const loginMessage = document.getElementById('login-message');
    const configMessage = document.getElementById('config-message');
    const probeMessage = document.getElementById('probe-message');
    const storageMessage = document.getElementById('storage-message');
    const secretInput = document.getElementById('admin-secret');
    const modelList = document.getElementById('model-list');
    const manageModelsButton = document.getElementById('manage-models-button');
    const modelModalBackdrop = document.getElementById('model-modal-backdrop');
    const modelManageList = document.getElementById('model-manage-list');
    const modelSearchInput = document.getElementById('model-search-input');

    const fields = {
      upstreamBaseUrl: document.getElementById('upstream-base-url'),
      upstreamApiKey: document.getElementById('upstream-api-key'),
      clientApiKey: document.getElementById('client-api-key'),
      apiTokenSigningSecret: document.getElementById('api-token-signing-secret'),
      apiTokenIssuer: document.getElementById('api-token-issuer'),
      apiTokenAudience: document.getElementById('api-token-audience'),
      apiTokenImageLimit: document.getElementById('api-token-image-limit'),
      authIssuer: document.getElementById('auth-issuer'),
      authClientId: document.getElementById('auth-client-id'),
      authClientSecret: document.getElementById('auth-client-secret'),
      authScopes: document.getElementById('auth-scopes'),
      publicBaseUrl: document.getElementById('public-base-url'),
      dailyPageLimit: document.getElementById('daily-page-limit'),
      storageEndpoint: document.getElementById('storage-endpoint'),
      storagePublicBaseUrl: document.getElementById('storage-public-base-url'),
      storageRegion: document.getElementById('storage-region'),
      storageBucket: document.getElementById('storage-bucket'),
      storageAccessKey: document.getElementById('storage-access-key'),
      storageSecretKey: document.getElementById('storage-secret-key'),
      storagePathPrefix: document.getElementById('storage-path-prefix'),
      rosemaryEnabled: document.getElementById('rosemary-enabled'),
      rosemaryApiBaseUrl: document.getElementById('rosemary-api-base-url'),
      rosemaryAppName: document.getElementById('rosemary-app-name'),
      rosemaryResVersion: document.getElementById('rosemary-res-version')
    };

    let modelCatalog = [];
    let selectedModels = [];
    let recommendedModels = [];
    let defaultModel = '';
    let modelRules = {};
    let modelSearchKeyword = '';
    let saveTimer = null;
    let isHydrating = false;

    function token() {
      return localStorage.getItem(TOKEN_KEY) || '';
    }

    function setSignedIn(isSignedIn) {
      loginCard.classList.toggle('hidden', isSignedIn);
      appCard.classList.toggle('hidden', !isSignedIn);
    }

    function buildPayload() {
      const payload = {};
      Object.entries(fields).forEach(([key, node]) => {
        payload[key] = node.value;
      });
      payload.availableModels = selectedModels;
      payload.recommendedModels = recommendedModels;
      payload.defaultModel = defaultModel;
      payload.modelRules = modelCatalog.map((model) => normalizeModelRule(model, modelRules[model] || {}));
      return payload;
    }

    async function persistConfig({ message = '配置已自动保存。', silent = false } = {}) {
      if (!token()) return;
      try {
        if (!silent) {
          configMessage.textContent = '正在保存配置...';
        }
        await api('/admin/api/config', {
          method: 'PUT',
          body: JSON.stringify(buildPayload())
        });
        if (!silent) {
          configMessage.textContent = message;
        }
      } catch (error) {
        configMessage.textContent = error.message;
      }
    }

    function schedulePersist(message = '配置已自动保存。') {
      if (isHydrating) return;
      if (saveTimer) {
        clearTimeout(saveTimer);
      }
      saveTimer = setTimeout(() => {
        saveTimer = null;
        persistConfig({ message });
      }, 500);
    }

    async function api(path, options = {}) {
      const headers = Object.assign(
        { 'Content-Type': 'application/json' },
        options.headers || {}
      );
      if (token()) {
        headers.Authorization = `Bearer \${token()}`;
      }
      const response = await fetch(path, Object.assign({}, options, { headers }));
      const contentType = response.headers.get('content-type') || '';
      const body = contentType.includes('application/json') ? await response.json() : await response.text();
      if (!response.ok) {
        const message = body && body.error ? body.error.message : response.statusText;
        throw new Error(message || '请求失败');
      }
      return body;
    }

    function uniqueModels(items) {
      const seen = new Set();
      const ordered = [];
      (items || []).forEach((item) => {
        const value = String(item || '').trim();
        if (!value || seen.has(value)) return;
        seen.add(value);
        ordered.push(value);
      });
      return ordered;
    }

    function ensureModelSelectionState() {
      modelCatalog = uniqueModels(modelCatalog);
      selectedModels = uniqueModels(selectedModels).filter((item) => modelCatalog.includes(item));
      recommendedModels = uniqueModels(recommendedModels).filter((item) => selectedModels.includes(item));
      if (!selectedModels.length && modelCatalog.includes(defaultModel)) {
        selectedModels = [defaultModel];
      }
      if (!selectedModels.length && modelCatalog.length) {
        selectedModels = [modelCatalog[0]];
      }
      if (!selectedModels.includes(defaultModel)) {
        defaultModel = selectedModels[0] || '';
      }
      const nextRules = {};
      modelCatalog.forEach((model) => {
        nextRules[model] = normalizeModelRule(model, Object.assign({}, modelRules[model] || {}, {
          enabled: selectedModels.includes(model),
          recommended: recommendedModels.includes(model)
        }));
      });
      modelRules = nextRules;
    }

    function normalizeModelRule(model, partial = {}) {
      const rawMultiplier = Number(partial.multiplier);
      return {
        name: model,
        enabled: partial.enabled !== false,
        recommended: partial.recommended === true,
        supportsChat: partial.supportsChat !== false,
        supportsSummary: partial.supportsSummary !== false,
        multiplier: Number.isFinite(rawMultiplier) && rawMultiplier > 0 ? rawMultiplier : 1
      };
    }

    function renderModels() {
      ensureModelSelectionState();

      if (!modelCatalog.length) {
        modelList.innerHTML = '<div class="model-empty">请先填写上游 Base URL 和 API Key，然后点击“测试连接并获取模型”。</div>';
        modelManageList.innerHTML = '<div class="model-empty">请先测试连接并获取模型。</div>';
        return;
      }

      const selectedTags = selectedModels.length
        ? selectedModels.map((model) => {
            const isRecommended = recommendedModels.includes(model);
            const isDefault = defaultModel === model;
            return `
              <span class="tag-chip">
                <span>\${model}</span>
                \${isRecommended ? '<span class="tag">推荐</span>' : ''}
                \${isDefault ? '<span class="tag">默认</span>' : ''}
                <span class="tag">x\${normalizeModelRule(model, modelRules[model]).multiplier}</span>
                <button type="button" data-remove-model="\${model}" aria-label="移除模型">×</button>
              </span>
            `;
          }).join('')
        : '<div class="model-empty">尚未选择要提供给客户端的模型。</div>';

      const recommendedTags = recommendedModels.length
        ? recommendedModels.map((model) => `<span class="tag-chip"><span>\${model}</span><button type="button" data-unrecommend-model="\${model}" aria-label="取消推荐">×</button></span>`).join('')
        : '<div class="model-empty">尚未设置推荐模型。</div>';

      modelList.innerHTML = `
        <section class="summary-card">
          <div>
            <h4>已提供给客户端的模型</h4>
            <div class="summary-meta">点击标签右侧的 × 可快捷移除。</div>
          </div>
          <div class="tag-list">\${selectedTags}</div>
        </section>
        <section class="summary-card">
          <div>
            <h4>推荐与默认模型</h4>
            <div class="summary-meta">默认模型：<strong>\${defaultModel || '未设置'}</strong> ｜ 每日额度：<strong>\${fields.dailyPageLimit.value || '100'}</strong> 页</div>
          </div>
          <div class="tag-list">\${recommendedTags}</div>
        </section>
      `;

      const filteredModels = modelCatalog
        .filter((model) =>
          model.toLowerCase().includes(modelSearchKeyword.toLowerCase())
        )
        .sort((left, right) => {
          const leftSelected = selectedModels.includes(left) ? 0 : 1;
          const rightSelected = selectedModels.includes(right) ? 0 : 1;
          if (leftSelected !== rightSelected) {
            return leftSelected - rightSelected;
          }
          return left.localeCompare(right, 'zh-CN');
        });

      modelManageList.innerHTML = filteredModels.length ? filteredModels.map((model) => {
        const isSelected = selectedModels.includes(model);
        const isRecommended = recommendedModels.includes(model);
        const isDefault = defaultModel === model;
        const rule = normalizeModelRule(model, modelRules[model] || {});
        return `
          <div class="model-item">
            <div class="model-main">
              <label class="inline-check">
                <input type="checkbox" data-role="available" data-model="\${model}" \${isSelected ? 'checked' : ''} />
                <span class="model-name">\${model}</span>
              </label>
              \${isRecommended ? '<span class="tag">推荐</span>' : ''}
              \${isDefault ? '<span class="tag">默认</span>' : ''}
              <span class="tag">x\${rule.multiplier}</span>
            </div>
            <div class="model-actions">
              <label class="inline-check">
                <input type="checkbox" data-role="recommended" data-model="\${model}" \${isRecommended ? 'checked' : ''} \${isSelected ? '' : 'disabled'} />
                <span>推荐</span>
              </label>
              <label class="inline-check">
                <input type="radio" name="default-model" data-role="default" data-model="\${model}" \${isDefault ? 'checked' : ''} \${isSelected ? '' : 'disabled'} />
                <span>设为默认</span>
              </label>
              <label class="inline-check">
                <input type="checkbox" data-role="supports-chat" data-model="\${model}" \${rule.supportsChat ? 'checked' : ''} />
                <span>支持聊天</span>
              </label>
              <label class="inline-check">
                <input type="checkbox" data-role="supports-summary" data-model="\${model}" \${rule.supportsSummary ? 'checked' : ''} />
                <span>支持摘要</span>
              </label>
              <label class="inline-check">
                <span>倍率</span>
                <input type="number" min="0.5" step="0.1" value="\${rule.multiplier}" data-role="multiplier" data-model="\${model}" style="width:88px;" />
              </label>
            </div>
          </div>
        `;
      }).join('') : '<div class="model-empty">没有匹配的模型，请尝试其他关键词。</div>';

      modelList.querySelectorAll('[data-remove-model]').forEach((node) => {
        node.addEventListener('click', () => {
          const model = node.dataset.removeModel;
          selectedModels = selectedModels.filter((item) => item !== model);
          recommendedModels = recommendedModels.filter((item) => item !== model);
          if (defaultModel === model) {
            defaultModel = selectedModels[0] || '';
          }
          renderModels();
          schedulePersist();
        });
      });

      modelList.querySelectorAll('[data-unrecommend-model]').forEach((node) => {
        node.addEventListener('click', () => {
          const model = node.dataset.unrecommendModel;
          recommendedModels = recommendedModels.filter((item) => item !== model);
          renderModels();
          schedulePersist();
        });
      });

      modelManageList.querySelectorAll('[data-role="available"]').forEach((node) => {
        node.addEventListener('change', (event) => {
          const model = event.target.dataset.model;
          if (event.target.checked) {
            selectedModels = uniqueModels([...selectedModels, model]);
            if (!defaultModel) {
              defaultModel = model;
            }
          } else {
            selectedModels = selectedModels.filter((item) => item !== model);
            recommendedModels = recommendedModels.filter((item) => item !== model);
            if (defaultModel === model) {
              defaultModel = selectedModels[0] || '';
            }
          }
          modelRules[model] = normalizeModelRule(model, Object.assign({}, modelRules[model] || {}, {
            enabled: event.target.checked
          }));
          renderModels();
          schedulePersist();
        });
      });

      modelManageList.querySelectorAll('[data-role="recommended"]').forEach((node) => {
        node.addEventListener('change', (event) => {
          const model = event.target.dataset.model;
          if (event.target.checked) {
            recommendedModels = uniqueModels([...recommendedModels, model]);
          } else {
            recommendedModels = recommendedModels.filter((item) => item !== model);
          }
          renderModels();
          schedulePersist();
        });
      });

      modelManageList.querySelectorAll('[data-role="default"]').forEach((node) => {
        node.addEventListener('change', (event) => {
          if (!event.target.checked) return;
          defaultModel = event.target.dataset.model;
          renderModels();
          schedulePersist();
        });
      });

      modelManageList.querySelectorAll('[data-role="supports-chat"]').forEach((node) => {
        node.addEventListener('change', (event) => {
          const model = event.target.dataset.model;
          modelRules[model] = normalizeModelRule(model, Object.assign({}, modelRules[model] || {}, {
            supportsChat: event.target.checked
          }));
          schedulePersist();
        });
      });

      modelManageList.querySelectorAll('[data-role="supports-summary"]').forEach((node) => {
        node.addEventListener('change', (event) => {
          const model = event.target.dataset.model;
          modelRules[model] = normalizeModelRule(model, Object.assign({}, modelRules[model] || {}, {
            supportsSummary: event.target.checked
          }));
          schedulePersist();
        });
      });

      modelManageList.querySelectorAll('[data-role="multiplier"]').forEach((node) => {
        node.addEventListener('change', (event) => {
          const model = event.target.dataset.model;
          modelRules[model] = normalizeModelRule(model, Object.assign({}, modelRules[model] || {}, {
            multiplier: event.target.value
          }));
          renderModels();
          schedulePersist();
        });
      });
    }

    function setModelModalVisible(visible) {
      modelModalBackdrop.classList.toggle('hidden', !visible);
      if (visible) {
        modelSearchInput.focus();
      }
    }

    async function restoreSession() {
      if (!token()) {
        setSignedIn(false);
        return;
      }
      try {
        await api('/admin/api/session');
        setSignedIn(true);
        await loadConfig();
      } catch (_) {
        localStorage.removeItem(TOKEN_KEY);
        setSignedIn(false);
      }
    }

    async function login() {
      loginMessage.textContent = '登录中...';
      try {
        const body = await api('/admin/api/login', {
          method: 'POST',
          body: JSON.stringify({ secret: secretInput.value })
        });
        localStorage.setItem(TOKEN_KEY, body.token);
        secretInput.value = '';
        loginMessage.textContent = '';
        setSignedIn(true);
        await loadConfig();
      } catch (error) {
        loginMessage.textContent = error.message;
      }
    }

    async function logout() {
      try {
        await api('/admin/api/logout', { method: 'POST' });
      } catch (_) {}
      localStorage.removeItem(TOKEN_KEY);
      setSignedIn(false);
      configMessage.textContent = '';
      probeMessage.textContent = '';
      storageMessage.textContent = '';
    }

    async function loadConfig() {
      configMessage.textContent = '正在加载配置...';
      try {
        const body = await api('/admin/api/config');
        isHydrating = true;
        document.getElementById('config-path').textContent = body.configPath;
        document.getElementById('dotenv-path').textContent = body.dotEnvPath;
        Object.entries(fields).forEach(([key, node]) => {
          const value = body.fields[key];
          node.value = value === undefined || value === null ? '' : String(value);
        });
        modelCatalog = uniqueModels(body.fields.modelCatalog || []);
        selectedModels = uniqueModels(body.fields.availableModels || []);
        recommendedModels = uniqueModels(body.fields.recommendedModels || []);
        defaultModel = body.fields.defaultModel || '';
        modelRules = {};
        (body.fields.modelRules || []).forEach((rule) => {
          if (!rule || !rule.name) return;
          modelRules[rule.name] = normalizeModelRule(rule.name, rule);
        });
        modelSearchKeyword = '';
        modelSearchInput.value = '';
        renderModels();
        isHydrating = false;
        configMessage.textContent = '配置已加载。';
      } catch (error) {
        isHydrating = false;
        configMessage.textContent = error.message;
      }
    }

    async function probeModels() {
      probeMessage.textContent = '正在测试连接并拉取模型...';
      try {
        const body = await api('/admin/api/upstream/test', {
          method: 'POST',
          body: JSON.stringify({
            upstreamBaseUrl: fields.upstreamBaseUrl.value,
            upstreamApiKey: fields.upstreamApiKey.value
          })
        });
        modelCatalog = uniqueModels(body.models || []);
        const previousRules = modelRules;
        modelRules = {};
        modelCatalog.forEach((model) => {
          modelRules[model] = normalizeModelRule(model, previousRules[model] || {});
        });
        selectedModels = selectedModels.filter((item) => modelCatalog.includes(item));
        recommendedModels = recommendedModels.filter((item) => modelCatalog.includes(item));
        if (!selectedModels.length && modelCatalog.length) {
          selectedModels = [modelCatalog[0]];
        }
        if (!defaultModel || !modelCatalog.includes(defaultModel)) {
          defaultModel = selectedModels[0] || modelCatalog[0] || '';
        }
        modelSearchKeyword = '';
        modelSearchInput.value = '';
        renderModels();
        probeMessage.textContent = `连接成功，已获取 \${modelCatalog.length} 个模型。`;
        await persistConfig({ message: '模型配置已保存。' });
      } catch (error) {
        probeMessage.textContent = error.message;
      }
    }

    async function testStorage() {
      storageMessage.textContent = '正在测试存储桶连接...';
      try {
        await api('/admin/api/storage/test', {
          method: 'POST',
          body: JSON.stringify({
            storageEndpoint: fields.storageEndpoint.value,
            storagePublicBaseUrl: fields.storagePublicBaseUrl.value,
            storageRegion: fields.storageRegion.value,
            storageBucket: fields.storageBucket.value,
            storageAccessKey: fields.storageAccessKey.value,
            storageSecretKey: fields.storageSecretKey.value,
            storagePathPrefix: fields.storagePathPrefix.value
          })
        });
        storageMessage.textContent = '存储桶连接正常，上传、下载和删除测试均已通过。';
      } catch (error) {
        storageMessage.textContent = error.message;
      }
    }

    async function saveConfig(event) {
      event.preventDefault();
      await persistConfig({ message: '配置已保存。' });
    }

    document.getElementById('login-button').addEventListener('click', login);
    document.getElementById('logout-button').addEventListener('click', logout);
    document.getElementById('reload-button').addEventListener('click', loadConfig);
    document.getElementById('probe-models-button').addEventListener('click', probeModels);
    document.getElementById('test-storage-button').addEventListener('click', testStorage);
    manageModelsButton.addEventListener('click', () => setModelModalVisible(true));
    document.getElementById('close-models-button').addEventListener('click', () => setModelModalVisible(false));
    document.getElementById('done-models-button').addEventListener('click', () => setModelModalVisible(false));
    modelModalBackdrop.addEventListener('click', (event) => {
      if (event.target === modelModalBackdrop) {
        setModelModalVisible(false);
      }
    });
    modelSearchInput.addEventListener('input', (event) => {
      modelSearchKeyword = event.target.value || '';
      renderModels();
    });
    Object.values(fields).forEach((node) => {
      node.addEventListener('input', () => schedulePersist());
      node.addEventListener('change', () => schedulePersist());
    });
    document.getElementById('config-form').addEventListener('submit', saveConfig);
    restoreSession();
  </script>
</body>
</html>
''';
}
