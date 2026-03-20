# Donut Workspace

This repository is now organized as a small monorepo:

- `donut_app/`: the existing Flutter application.
- `donut_backend/`: a newly initialized Dart Frog backend service.

## App

```bash
cd donut_app
flutter pub get
flutter run
```

## Backend

```bash
cd donut_backend
export DONUT_UPSTREAM_API_KEY="sk-your-real-provider-key"
dart pub get
dart_frog dev
```

Use `DONUT_UPSTREAM_BASE_URL` if you want to target a non-OpenAI compatible
provider base URL, and `DONUT_CLIENT_API_KEY` to control the app-facing bearer
key accepted by the Donut gateway.
