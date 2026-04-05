# donut_backend

Dart Frog backend scaffold for the Donut workspace.

## Development

```bash
dart pub get
dart_frog dev
```

## Docs

- [PDF Native Document Input + Context Cache Design](./docs/pdf_native_context_and_prompt_cache.md)

## OIDC BFF Auth

The backend now supports a desktop-friendly BFF login flow:

1. The Flutter app calls `POST /auth/login/start`.
2. The backend builds an OIDC authorization URL.
3. The app opens the system browser for third-party sign-in.
4. The provider redirects back to `/auth/callback`.
5. The app polls `/auth/login/poll/:token` until the backend returns a Donut
   session token.
6. Protected requests use `Authorization: Bearer <donut_session_token>`.

Required environment variables:

```bash
export DONUT_AUTH_ISSUER="https://your-issuer.example.com"
export DONUT_AUTH_CLIENT_ID="your-client-id"
export DONUT_AUTH_CLIENT_SECRET="your-client-secret"
```

Optional:

```bash
export DONUT_AUTH_SCOPES="openid profile email"
export DONUT_PUBLIC_BASE_URL="https://your-public-gateway.example.com"
```

## Admin Config Portal

The backend also ships with a lightweight admin website at `/admin`.

Required:

```bash
export DONUT_ADMIN_SECRET="choose-a-strong-secret"
```

Recommended:

```bash
export DONUT_ENV_FILE=".env"
export DONUT_CONFIG_PATH=".donut_runtime_config.json"
```

Behavior:

1. The admin secret is read from environment variables or `.env`.
2. Administrators sign in at `/admin`.
3. Editable settings are written to ObjectBox-backed runtime storage.
4. Runtime overrides take precedence over `.env` and are applied to new
   requests immediately.

## Legacy Data Migration

When deploying a newer backend to a server that still has the old JSON files,
startup migration will:

1. Detect legacy files such as `DONUT_CONFIG_PATH`, `*.usage.json`, and
   `*.sessions.json`.
2. Import the data into the new ObjectBox database.
3. Verify that the imported data matches the legacy source.
4. Copy the original JSON files into `DONUT_CONFIG_PATH.legacy_backup/...`.
5. Delete the original legacy JSON files only after the backup has been
   verified.

If verification fails or the existing ObjectBox data differs from the legacy
file contents, the backend keeps the original file and skips deletion so the
data can be inspected manually.

The portal currently manages:

- upstream gateway base URL and API keys
- default model and available model list
- OIDC issuer, client ID, client secret, scopes, and public callback base URL

## Test

```bash
dart test
```
