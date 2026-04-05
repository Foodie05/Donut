#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DONUT_APP_DIR="$ROOT_DIR/donut_app"
DONUT_BACKEND_DIR="$ROOT_DIR/donut_backend"
WEBSITE_DIR="$ROOT_DIR/website"
DEPLOY_DIR="$ROOT_DIR/deploy"
NOTARIZE_ENV_FILE="$ROOT_DIR/notarize.txt"
ARTIFACTS_ROOT="$ROOT_DIR/release_artifacts"
API_BASE_URL="https://apidonut.cruty.cn"
BACKEND_PORT="8092"

usage() {
  cat <<'EOF'
Usage:
  ./build_release_bundle.sh --version=x.y.z+n

Options:
  --version=x.y.z+n   Release version used for app build metadata and artifact folder naming.
  --web               Build website artifacts only.
  --server            Build backend linux-x64 artifacts only.
  --dmg               Build macOS app and DMG only.
  --no-validate       When used with --dmg, build and sign the DMG but skip notarization/stapling.
  --apk               Build Android APK only.
  --ipa               Build iPadOS/iOS IPA only.
  --exe               Build Windows artifacts only.
  --all               Build all targets (default when no target flags are given).
  -h, --help          Show this help text.

Optional macOS signing / notarization environment variables:
  MACOS_CODESIGN_IDENTITY         Developer ID Application identity for codesign.
  APPLE_ID                        Apple ID used by notarytool.
  APPLE_TEAM_ID                   Apple Developer team ID.
  APPLE_APP_SPECIFIC_PASSWORD     App-specific password used by notarytool.

If ./notarize.txt exists, the script will source it automatically before the
macOS build.

Outputs:
  release_artifacts/<version>/
EOF
}

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command not found: $cmd" >&2
    exit 1
  fi
}

VERSION=""
BUILD_WEB=0
BUILD_SERVER=0
BUILD_DMG=0
BUILD_APK=0
BUILD_IPA=0
BUILD_EXE=0
SKIP_DMG_VALIDATION=0
TARGET_FLAGS_SET=0
for arg in "$@"; do
  case "$arg" in
    --version=*)
      VERSION="${arg#*=}"
      ;;
    --web)
      BUILD_WEB=1
      TARGET_FLAGS_SET=1
      ;;
    --server)
      BUILD_SERVER=1
      TARGET_FLAGS_SET=1
      ;;
    --dmg)
      BUILD_DMG=1
      TARGET_FLAGS_SET=1
      ;;
    --no-validate)
      SKIP_DMG_VALIDATION=1
      ;;
    --apk)
      BUILD_APK=1
      TARGET_FLAGS_SET=1
      ;;
    --ipa)
      BUILD_IPA=1
      TARGET_FLAGS_SET=1
      ;;
    --exe)
      BUILD_EXE=1
      TARGET_FLAGS_SET=1
      ;;
    --all)
      BUILD_WEB=1
      BUILD_SERVER=1
      BUILD_DMG=1
      BUILD_APK=1
      BUILD_IPA=1
      BUILD_EXE=1
      TARGET_FLAGS_SET=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$VERSION" ]]; then
  echo "--version is required." >&2
  usage >&2
  exit 1
fi

if [[ "$TARGET_FLAGS_SET" -eq 0 ]]; then
  BUILD_WEB=1
  BUILD_SERVER=1
  BUILD_DMG=1
  BUILD_APK=1
  BUILD_IPA=1
  BUILD_EXE=1
fi

if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+){2}\+[0-9]+$ ]]; then
  echo "Invalid version format: $VERSION" >&2
  echo "Expected: x.y.z+n" >&2
  exit 1
fi

BUILD_NAME="${VERSION%%+*}"
BUILD_NUMBER="${VERSION##*+}"
ARTIFACT_DIR="$ARTIFACTS_ROOT/$VERSION"
WEBSITE_ARTIFACT_DIR="$ARTIFACT_DIR/website"
BACKEND_ARTIFACT_DIR="$ARTIFACT_DIR/backend"
APP_ARTIFACT_DIR="$ARTIFACT_DIR/app"
MACOS_ARTIFACT_DIR="$APP_ARTIFACT_DIR/macos"
ANDROID_ARTIFACT_DIR="$APP_ARTIFACT_DIR/android"
IOS_ARTIFACT_DIR="$APP_ARTIFACT_DIR/ios"
WINDOWS_ARTIFACT_DIR="$APP_ARTIFACT_DIR/windows"
METADATA_FILE="$ARTIFACT_DIR/ARTIFACTS.txt"
BACKEND_BINARY_NAME="donut_backend_linux_x64"
BACKEND_PACKAGE_NAME="donut_backend_linux_x64.tar.gz"
BACKEND_CONFIG_NAME="donut_backend.config.json"
BACKEND_RUN_SCRIPT_NAME="start_backend.sh"
BACKEND_DOCKER_DIR_NAME="docker"
WEBSITE_PACKAGE_NAME="website-dist.tar.gz"
MACOS_APP_NAME="Donut"
MACOS_DMG_NAME="${MACOS_APP_NAME}-${VERSION}.dmg"
ANDROID_APK_NAME="${MACOS_APP_NAME}-${VERSION}.apk"
IOS_IPA_NAME="${MACOS_APP_NAME}-${VERSION}.ipa"
WINDOWS_PORTABLE_ZIP_NAME="${MACOS_APP_NAME}-${VERSION}-windows-x64.zip"
WINDOWS_INSTALLER_EXE_NAME="${MACOS_APP_NAME}-${VERSION}-windows-x64-setup.exe"

require_command bash
require_command cp
require_command tar

export https_proxy="http://127.0.0.1:7897"
export http_proxy="http://127.0.0.1:7897"
export all_proxy="socks5://127.0.0.1:7897"

if [[ -f "$NOTARIZE_ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$NOTARIZE_ENV_FILE"
fi

mkdir -p "$ARTIFACT_DIR"

build_website() {
  require_command npm
  echo "==> Building website"
  mkdir -p "$WEBSITE_ARTIFACT_DIR"
  pushd "$WEBSITE_DIR" >/dev/null
  if [[ ! -d node_modules ]]; then
    npm ci
  fi
  npm run build
  popd >/dev/null

  rm -rf "$WEBSITE_ARTIFACT_DIR/dist"
  mkdir -p "$WEBSITE_ARTIFACT_DIR/dist"
  cp -R "$WEBSITE_DIR/dist/." "$WEBSITE_ARTIFACT_DIR/dist/"
  tar -czf "$WEBSITE_ARTIFACT_DIR/$WEBSITE_PACKAGE_NAME" -C "$WEBSITE_DIR" dist
}

write_backend_runtime_config() {
  cp "$DEPLOY_DIR/backend.config.template.json" \
    "$BACKEND_ARTIFACT_DIR/$BACKEND_CONFIG_NAME"
}

write_backend_run_script() {
  cat > "$BACKEND_ARTIFACT_DIR/$BACKEND_RUN_SCRIPT_NAME" <<EOF
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
export PORT=$BACKEND_PORT
export DONUT_CONFIG_PATH="\$SCRIPT_DIR/$BACKEND_CONFIG_NAME"
exec "\$SCRIPT_DIR/$BACKEND_BINARY_NAME"
EOF
  chmod +x "$BACKEND_ARTIFACT_DIR/$BACKEND_RUN_SCRIPT_NAME"
}

copy_backend_deploy_bundle() {
  local docker_artifact_dir="$BACKEND_ARTIFACT_DIR/$BACKEND_DOCKER_DIR_NAME"
  mkdir -p "$docker_artifact_dir/data"
  cp "$DEPLOY_DIR/README.md" "$docker_artifact_dir/README.md"
  cp "$DEPLOY_DIR/data/donut_backend.config.example.json" \
    "$docker_artifact_dir/data/donut_backend.config.example.json"
  cp "$BACKEND_ARTIFACT_DIR/$BACKEND_BINARY_NAME" "$docker_artifact_dir/$BACKEND_BINARY_NAME"
  cat > "$docker_artifact_dir/Dockerfile" <<EOF
FROM gcr.io/distroless/cc-debian12

WORKDIR /app

COPY $BACKEND_BINARY_NAME /app/$BACKEND_BINARY_NAME

ENV PORT=8092
ENV DONUT_ENV=production
ENV DONUT_CONFIG_PATH=/data/donut_backend.config.json
ENV DONUT_LOG_PATH=/data/donut_backend.log

EXPOSE 8092

ENTRYPOINT ["/app/$BACKEND_BINARY_NAME"]
EOF
  cat > "$docker_artifact_dir/docker-compose.yml" <<'EOF'
services:
  donut_backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: donut_backend
    restart: unless-stopped
    ports:
      - "8092:8092"
    environment:
      PORT: "8092"
      DONUT_ENV: "production"
      DONUT_CONFIG_PATH: "/data/donut_backend.config.json"
      DONUT_LOG_PATH: "/data/donut_backend.log"
      DONUT_LOG_CONSOLE: "true"
      DONUT_LOG_FILE: "true"
    volumes:
      - ./data:/data
EOF
}

build_backend() {
  require_command dart
  require_command dart_frog
  echo "==> Building donut_backend for linux-x64"
  mkdir -p "$BACKEND_ARTIFACT_DIR"
  pushd "$DONUT_BACKEND_DIR" >/dev/null
  dart pub get
  dart_frog build
  dart compile exe \
    --target-os linux \
    --target-arch x64 \
    build/bin/server.dart \
    -o "$BACKEND_ARTIFACT_DIR/$BACKEND_BINARY_NAME"
  popd >/dev/null

  chmod +x "$BACKEND_ARTIFACT_DIR/$BACKEND_BINARY_NAME"
  write_backend_runtime_config
  write_backend_run_script
  copy_backend_deploy_bundle
  tar -czf \
    "$BACKEND_ARTIFACT_DIR/$BACKEND_PACKAGE_NAME" \
    -C "$BACKEND_ARTIFACT_DIR" \
    "$BACKEND_BINARY_NAME" \
    "$BACKEND_CONFIG_NAME" \
    "$BACKEND_RUN_SCRIPT_NAME" \
    "$BACKEND_DOCKER_DIR_NAME"
}

detect_codesign_identity() {
  if [[ -n "${MACOS_CODESIGN_IDENTITY:-}" ]]; then
    local exact
    exact="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' -v target="$MACOS_CODESIGN_IDENTITY" '$2 == target {print $2; exit}')"
    if [[ -n "$exact" ]]; then
      printf '%s\n' "$exact"
      return
    fi

    local developer_id_match
    developer_id_match="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' -v target="$MACOS_CODESIGN_IDENTITY" 'index($2, "Developer ID Application:") && index($2, target) {print $2; exit}')"
    if [[ -n "$developer_id_match" ]]; then
      printf '%s\n' "$developer_id_match"
      return
    fi
  fi

  local detected
  detected="$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/Developer ID Application/ {print $2; exit}')"
  printf '%s\n' "$detected"
}

extract_team_id_from_identity() {
  local identity="$1"
  if [[ "$identity" =~ \(([A-Z0-9]{10})\)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return
  fi
  printf '\n'
}

sign_macos_app_if_possible() {
  local app_bundle_path="$1"
  local identity="$2"

  if [[ -z "$identity" ]]; then
    echo "Skipping macOS codesign: MACOS_CODESIGN_IDENTITY not provided and no Developer ID Application identity auto-detected."
    return
  fi

  echo "==> Codesigning macOS app with identity: $identity"
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$identity" \
    "$app_bundle_path"
}

create_macos_dmg() {
  local app_bundle_path="$1"
  local dmg_path="$2"
  local stage_dir="$3"

  rm -rf "$stage_dir"
  mkdir -p "$stage_dir"
  cp -R "$app_bundle_path" "$stage_dir/"
  if [[ "$SKIP_DMG_VALIDATION" -eq 1 ]]; then
    write_macos_install_guide "$stage_dir/安装教程.html"
  fi
  rm -f "$dmg_path"

  create-dmg \
    --volname "$MACOS_APP_NAME" \
    --window-pos 200 120 \
    --window-size 800 420 \
    --icon-size 120 \
    --icon "$MACOS_APP_NAME.app" 220 190 \
    --icon "Applications" 580 190 \
    --hide-extension "$MACOS_APP_NAME.app" \
    --app-drop-link 580 190 \
    --skip-jenkins \
    --sandbox-safe \
    "$dmg_path" \
    "$stage_dir"
}

write_macos_install_guide() {
  local guide_path="$1"
  cat > "$guide_path" <<'EOF'
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Donut 安装教程</title>
    <style>
      :root {
        color-scheme: light;
        --bg: #f8f3ee;
        --card: #fffaf6;
        --text: #241b1a;
        --muted: #6f5b57;
        --accent: #8c3b3b;
        --border: #ead7d1;
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
        background: linear-gradient(180deg, #fcf7f2 0%, var(--bg) 100%);
        color: var(--text);
      }
      .wrap {
        max-width: 880px;
        margin: 0 auto;
        padding: 40px 20px 60px;
      }
      .card {
        background: var(--card);
        border: 1px solid var(--border);
        border-radius: 24px;
        padding: 32px;
        box-shadow: 0 20px 40px rgba(79, 44, 38, 0.08);
      }
      h1 {
        margin: 0 0 12px;
        font-size: 40px;
        line-height: 1.1;
      }
      p {
        margin: 0 0 18px;
        color: var(--muted);
        font-size: 18px;
        line-height: 1.7;
      }
      .step {
        margin-top: 22px;
        padding: 20px 22px;
        border-radius: 18px;
        background: #fff;
        border: 1px solid var(--border);
      }
      .step h2 {
        margin: 0 0 10px;
        font-size: 22px;
      }
      ol {
        margin: 0;
        padding-left: 22px;
      }
      li {
        margin: 10px 0;
        font-size: 17px;
        line-height: 1.7;
      }
      .tip {
        margin-top: 24px;
        padding: 18px 20px;
        border-radius: 16px;
        background: #fff3f0;
        color: #6a3029;
        border: 1px solid #efc8bf;
      }
      strong {
        color: var(--accent);
      }
      code {
        padding: 2px 8px;
        border-radius: 999px;
        background: #f5e7e3;
        color: #6d2e2e;
        font-size: 0.95em;
      }
    </style>
  </head>
  <body>
    <div class="wrap">
      <div class="card">
        <h1>Donut 安装教程</h1>
        <p>这个安装包为未公证构建版本。首次打开时，macOS 可能会提示“无法验证”或“可能包含恶意软件”。按照下面步骤操作即可正常安装和运行。</p>

        <div class="step">
          <h2>第一步：安装应用</h2>
          <ol>
            <li>先将 <strong>Donut.app</strong> 拖动到 <strong>应用程序</strong> 文件夹。</li>
            <li>等待复制完成后，再去“应用程序”中打开 Donut。</li>
          </ol>
        </div>

        <div class="step">
          <h2>第二步：如果系统提示无法验证</h2>
          <ol>
            <li>看到“无法验证开发者”或“可能包含恶意软件”时，先关闭提示框。</li>
            <li>打开 <code>系统设置</code>。</li>
            <li>进入 <code>隐私与安全性</code>。</li>
            <li>在页面下方找到关于 <strong>Donut</strong> 的安全提示。</li>
            <li>点击 <code>仍要打开</code>。</li>
            <li>再次确认打开后，后续通常就可以正常启动了。</li>
          </ol>
        </div>

        <div class="tip">
          如果你是从 Finder 里首次打开，也可以尝试对 Donut 右键，然后选择“打开”。部分 macOS 版本会在第二次确认后允许继续运行。
        </div>
      </div>
    </div>
  </body>
</html>
EOF
}

notarize_macos_dmg_if_possible() {
  local dmg_path="$1"
  local identity="$2"
  local effective_team_id="${APPLE_TEAM_ID:-}"

  if [[ -z "$identity" ]]; then
    echo "Skipping notarization: macOS artifact is not signed with a Developer ID Application identity."
    return
  fi

  if [[ -z "$effective_team_id" || ! "$effective_team_id" =~ ^[A-Z0-9]{10}$ ]]; then
    effective_team_id="$(extract_team_id_from_identity "$identity")"
  fi

  if [[ -z "${APPLE_ID:-}" || -z "$effective_team_id" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    echo "Skipping notarization: set APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD to enable automatic notary submission."
    return
  fi

  echo "==> Codesigning DMG"
  codesign \
    --force \
    --sign "$identity" \
    "$dmg_path"

  echo "==> Submitting DMG for notarization"
  xcrun notarytool submit \
    "$dmg_path" \
    --apple-id "$APPLE_ID" \
    --team-id "$effective_team_id" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait

  echo "==> Stapling notarization ticket"
  xcrun stapler staple "$dmg_path"
}

build_macos_app() {
  require_command flutter
  require_command create-dmg
  require_command codesign
  require_command security
  echo "==> Building macOS DMG"
  mkdir -p "$MACOS_ARTIFACT_DIR"
  pushd "$DONUT_APP_DIR" >/dev/null
  flutter pub get
  flutter build macos \
    --release \
    --build-name="$BUILD_NAME" \
    --build-number="$BUILD_NUMBER" \
    --dart-define=DONUT_API_BASE_URL="$API_BASE_URL"
  popd >/dev/null

  local app_bundle_path="$DONUT_APP_DIR/build/macos/Build/Products/Release/${MACOS_APP_NAME}.app"
  local dmg_path="$MACOS_ARTIFACT_DIR/$MACOS_DMG_NAME"
  local dmg_stage_dir="$DONUT_APP_DIR/build/dmg_stage_release_bundle"
  local identity
  identity="$(detect_codesign_identity)"

  sign_macos_app_if_possible "$app_bundle_path" "$identity"
  create_macos_dmg "$app_bundle_path" "$dmg_path" "$dmg_stage_dir"
  printf '%s\n' "$identity" > "$MACOS_ARTIFACT_DIR/.codesign_identity"
}

build_android_apk() {
  require_command flutter
  echo "==> Building Android APK"
  mkdir -p "$ANDROID_ARTIFACT_DIR"
  pushd "$DONUT_APP_DIR" >/dev/null
  flutter build apk \
    --release \
    --build-name="$BUILD_NAME" \
    --build-number="$BUILD_NUMBER" \
    --dart-define=DONUT_API_BASE_URL="$API_BASE_URL"
  popd >/dev/null

  cp \
    "$DONUT_APP_DIR/build/app/outputs/flutter-apk/app-release.apk" \
    "$ANDROID_ARTIFACT_DIR/$ANDROID_APK_NAME"
}

build_ios_ipa() {
  require_command flutter
  require_command xcodebuild
  echo "==> Building iPadOS/iOS IPA"
  mkdir -p "$IOS_ARTIFACT_DIR"
  pushd "$DONUT_APP_DIR" >/dev/null
  flutter pub get
  flutter build ipa \
    --release \
    --build-name="$BUILD_NAME" \
    --build-number="$BUILD_NUMBER" \
    --dart-define=DONUT_API_BASE_URL="$API_BASE_URL" \
    --export-method="${IOS_EXPORT_METHOD:-app-store}"
  popd >/dev/null

  local ipa_output_dir="$DONUT_APP_DIR/build/ios/ipa"
  local built_ipa_path
  built_ipa_path="$(find "$ipa_output_dir" -maxdepth 1 -type f -name '*.ipa' | head -n 1)"
  if [[ -z "$built_ipa_path" || ! -f "$built_ipa_path" ]]; then
    echo "IPA build completed but no .ipa file was found under $ipa_output_dir" >&2
    exit 1
  fi
  cp "$built_ipa_path" "$IOS_ARTIFACT_DIR/$IOS_IPA_NAME"
}

write_windows_install_scripts() {
  local output_dir="$1"
  cat > "$output_dir/install.bat" <<'EOF'
@echo off
setlocal
PowerShell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
endlocal
EOF
  cat > "$output_dir/install.ps1" <<'EOF'
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$targetDir = Join-Path $env:LOCALAPPDATA 'Programs\Donut'
New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -Path (Join-Path $scriptDir 'Donut\*') -Destination $targetDir -Recurse -Force
$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut((Join-Path $env:USERPROFILE 'Desktop\Donut.lnk'))
$shortcut.TargetPath = Join-Path $targetDir 'Donut.exe'
$shortcut.WorkingDirectory = $targetDir
$shortcut.IconLocation = (Join-Path $targetDir 'Donut.exe')
$shortcut.Save()
Start-Process (Join-Path $targetDir 'Donut.exe')
Write-Host "Installed to $targetDir"
EOF
}

build_windows_exe() {
  require_command flutter
  require_command tar
  echo "==> Building Windows artifacts"
  mkdir -p "$WINDOWS_ARTIFACT_DIR"
  pushd "$DONUT_APP_DIR" >/dev/null
  flutter pub get
  flutter build windows \
    --release \
    --build-name="$BUILD_NAME" \
    --build-number="$BUILD_NUMBER" \
    --dart-define=DONUT_API_BASE_URL="$API_BASE_URL"
  popd >/dev/null

  local built_dir="$DONUT_APP_DIR/build/windows/x64/runner/Release"
  local stage_dir="$WINDOWS_ARTIFACT_DIR/stage"
  rm -rf "$stage_dir"
  mkdir -p "$stage_dir/Donut"
  cp -R "$built_dir/." "$stage_dir/Donut/"
  write_windows_install_scripts "$stage_dir"

  (
    cd "$stage_dir"
    tar -a -cf "$WINDOWS_ARTIFACT_DIR/$WINDOWS_PORTABLE_ZIP_NAME" .
  )

  local sfx_module=""
  if command -v 7z >/dev/null 2>&1; then
    local seven_zip_bin
    seven_zip_bin="$(command -v 7z)"
    local seven_zip_dir
    seven_zip_dir="$(cd "$(dirname "$seven_zip_bin")" && pwd)"
    if [[ -f "$seven_zip_dir/7z.sfx" ]]; then
      sfx_module="$seven_zip_dir/7z.sfx"
    elif [[ -f "$seven_zip_dir/7zS.sfx" ]]; then
      sfx_module="$seven_zip_dir/7zS.sfx"
    fi

    if [[ -n "$sfx_module" ]]; then
      local payload_7z="$WINDOWS_ARTIFACT_DIR/windows_payload.7z"
      local sfx_config="$WINDOWS_ARTIFACT_DIR/windows_sfx_config.txt"
      rm -f "$payload_7z" "$sfx_config" "$WINDOWS_ARTIFACT_DIR/$WINDOWS_INSTALLER_EXE_NAME"
      (
        cd "$stage_dir"
        7z a -t7z -mx=9 "$payload_7z" . >/dev/null
      )
      cat > "$sfx_config" <<'EOF'
;!@Install@!UTF-8!
Title="Donut Installer"
BeginPrompt="Install Donut to your local profile and launch it now?"
RunProgram="install.bat"
GUIMode="1"
;!@InstallEnd@!
EOF
      cat "$sfx_module" "$sfx_config" "$payload_7z" > "$WINDOWS_ARTIFACT_DIR/$WINDOWS_INSTALLER_EXE_NAME"
      chmod +x "$WINDOWS_ARTIFACT_DIR/$WINDOWS_INSTALLER_EXE_NAME" || true
      rm -f "$payload_7z" "$sfx_config"
    fi
  fi
}

finalize_macos_notarization() {
  if [[ "$SKIP_DMG_VALIDATION" -eq 1 ]]; then
    echo "Skipping notarization and stapling because --no-validate was provided."
    rm -f "$MACOS_ARTIFACT_DIR/.codesign_identity"
    return
  fi
  require_command xcrun
  local dmg_path="$MACOS_ARTIFACT_DIR/$MACOS_DMG_NAME"
  local identity=""
  if [[ -f "$MACOS_ARTIFACT_DIR/.codesign_identity" ]]; then
    identity="$(cat "$MACOS_ARTIFACT_DIR/.codesign_identity")"
  fi
  notarize_macos_dmg_if_possible "$dmg_path" "$identity"
  rm -f "$MACOS_ARTIFACT_DIR/.codesign_identity"
}

write_metadata() {
  local sections=()
  sections+=("Release version: $VERSION")

  if [[ "$BUILD_WEB" -eq 1 ]]; then
    sections+=("")
    sections+=("Website:")
    sections+=("  Dist directory: $WEBSITE_ARTIFACT_DIR/dist")
    sections+=("  Package: $WEBSITE_ARTIFACT_DIR/$WEBSITE_PACKAGE_NAME")
  fi

  if [[ "$BUILD_SERVER" -eq 1 ]]; then
    sections+=("")
    sections+=("Backend:")
    sections+=("  Linux binary: $BACKEND_ARTIFACT_DIR/$BACKEND_BINARY_NAME")
    sections+=("  Runtime config: $BACKEND_ARTIFACT_DIR/$BACKEND_CONFIG_NAME")
    sections+=("  Start script: $BACKEND_ARTIFACT_DIR/$BACKEND_RUN_SCRIPT_NAME")
    sections+=("  Docker bundle: $BACKEND_ARTIFACT_DIR/$BACKEND_DOCKER_DIR_NAME")
    sections+=("  Package: $BACKEND_ARTIFACT_DIR/$BACKEND_PACKAGE_NAME")
    sections+=("  Listen port: $BACKEND_PORT")
    sections+=("  Admin URL (when deployed behind your domain): $API_BASE_URL/admin")
    sections+=("  OIDC callback URL: $API_BASE_URL/auth/callback")
  fi

  if [[ "$BUILD_DMG" -eq 1 || "$BUILD_APK" -eq 1 || "$BUILD_IPA" -eq 1 || "$BUILD_EXE" -eq 1 ]]; then
    sections+=("")
    sections+=("Apps:")
    if [[ "$BUILD_DMG" -eq 1 ]]; then
      sections+=("  macOS DMG: $MACOS_ARTIFACT_DIR/$MACOS_DMG_NAME")
    fi
    if [[ "$BUILD_APK" -eq 1 ]]; then
      sections+=("  Android APK: $ANDROID_ARTIFACT_DIR/$ANDROID_APK_NAME")
    fi
    if [[ "$BUILD_IPA" -eq 1 ]]; then
      sections+=("  iPadOS/iOS IPA: $IOS_ARTIFACT_DIR/$IOS_IPA_NAME")
      sections+=("  iOS export method: ${IOS_EXPORT_METHOD:-app-store}")
    fi
    if [[ "$BUILD_EXE" -eq 1 ]]; then
      sections+=("  Windows ZIP: $WINDOWS_ARTIFACT_DIR/$WINDOWS_PORTABLE_ZIP_NAME")
      if [[ -f "$WINDOWS_ARTIFACT_DIR/$WINDOWS_INSTALLER_EXE_NAME" ]]; then
        sections+=("  Windows self-extracting installer EXE: $WINDOWS_ARTIFACT_DIR/$WINDOWS_INSTALLER_EXE_NAME")
      else
        sections+=("  Windows self-extracting installer EXE: not generated (install 7-Zip CLI with 7z.sfx/7zS.sfx available)")
      fi
    fi
  fi

  printf '%s\n' "${sections[@]}" > "$METADATA_FILE"
}

if [[ "$BUILD_WEB" -eq 1 ]]; then
  build_website
fi

if [[ "$BUILD_SERVER" -eq 1 ]]; then
  build_backend
fi

if [[ "$BUILD_DMG" -eq 1 ]]; then
  build_macos_app
fi

if [[ "$BUILD_APK" -eq 1 ]]; then
  build_android_apk
fi

if [[ "$BUILD_IPA" -eq 1 ]]; then
  build_ios_ipa
fi

if [[ "$BUILD_EXE" -eq 1 ]]; then
  build_windows_exe
fi

if [[ "$BUILD_DMG" -eq 1 ]]; then
  finalize_macos_notarization
fi

write_metadata

echo
echo "Release artifacts ready under:"
echo "  $ARTIFACT_DIR"
echo
cat "$METADATA_FILE"
