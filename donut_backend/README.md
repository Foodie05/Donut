# donut_backend

Dart Frog backend for Donut. It exposes a small OpenAI-compatible gateway so the
existing Flutter app can call `chat/completions` against Donut first, while the
backend forwards requests to the real upstream provider.

## Environment variables

```bash
export DONUT_UPSTREAM_BASE_URL="https://api.openai.com/v1"
export DONUT_UPSTREAM_API_KEY="sk-your-real-provider-key"
export DONUT_CLIENT_API_KEY="donut-local-client-key"
```

## Development

```bash
dart pub get
dart_frog dev
```

The gateway currently proxies:

- `POST /v1/chat/completions`
- `GET /v1/models`
- `GET /v1/models/:model`

Streaming responses are passed through as upstream `text/event-stream` bytes so
OpenAI-style streaming remains intact for the app.

## Test

```bash
dart test
```
