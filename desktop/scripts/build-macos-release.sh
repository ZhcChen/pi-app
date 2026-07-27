#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --arch universal" >&2
}

ARCH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --arch)
      ARCH="${2:-}"
      shift 2
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

case "${ARCH}" in
  universal) ;;
  *)
    usage
    exit 1
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_DIR="$(cd "${DESKTOP_DIR}/.." && pwd)"
PUBSPEC_PATH="${DESKTOP_DIR}/pubspec.yaml"
VERSION_SPEC="$(awk '/^version:[[:space:]]*/ { sub(/^version:[[:space:]]*/, ""); print; exit }' "${PUBSPEC_PATH}")"

if [[ -z "${VERSION_SPEC}" ]]; then
  echo "Could not read version from ${PUBSPEC_PATH}." >&2
  exit 1
fi

BUILD_NAME="${VERSION_SPEC%%+*}"
BUILD_NUMBER="${VERSION_SPEC#*+}"
if [[ "${BUILD_NUMBER}" == "${VERSION_SPEC}" ]]; then
  BUILD_NUMBER="1"
fi

APP_PATH="${DESKTOP_DIR}/build/macos/Build/Products/Release/Pi App.app"
APP_BINARY="${APP_PATH}/Contents/MacOS/Pi App"
RELEASE_DIR="${PI_RELEASE_DIR:-${REPO_DIR}/release/macos-${ARCH}}"
BUNDLE_PATH="${RELEASE_DIR}/Pi App.app"
DMG_PATH="${RELEASE_DIR}/Pi-App-${BUILD_NAME}-macos-${ARCH}.dmg"

cd "${DESKTOP_DIR}"
flutter build macos --release --build-name "${BUILD_NAME}" --build-number "${BUILD_NUMBER}"

if [[ ! -x "${APP_BINARY}" ]]; then
  echo "Expected macOS app binary is missing: ${APP_BINARY}" >&2
  exit 1
fi

ACTUAL_ARCHS="$(lipo -archs "${APP_BINARY}")"
for EXPECTED_ARCH in arm64 x86_64; do
  if [[ " ${ACTUAL_ARCHS} " != *" ${EXPECTED_ARCH} "* ]]; then
    echo "Built app architectures (${ACTUAL_ARCHS}) do not include ${EXPECTED_ARCH}." >&2
    exit 1
  fi
done

# Flutter plugins embed frameworks and dylibs, so sign the complete bundle after build.
codesign --force --deep --sign - "${APP_PATH}"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

SIGNATURE_DETAILS="$(codesign -d --verbose=4 "${APP_PATH}" 2>&1 || true)"
if ! grep -qi "Signature=adhoc" <<<"${SIGNATURE_DETAILS}"; then
  echo "Expected an ad-hoc signature on ${APP_PATH}." >&2
  echo "${SIGNATURE_DETAILS}" >&2
  exit 1
fi

ENTITLEMENTS="$(codesign -d --entitlements :- "${APP_PATH}" 2>&1 || true)"
if grep -q "com.apple.security.app-sandbox" <<<"${ENTITLEMENTS}"; then
  echo "Release bundle must not include com.apple.security.app-sandbox." >&2
  exit 1
fi

rm -rf "${RELEASE_DIR}"
mkdir -p "${RELEASE_DIR}"
ditto "${APP_PATH}" "${BUNDLE_PATH}"
hdiutil create -quiet -volname "Pi App" -srcfolder "${BUNDLE_PATH}" -ov -format UDZO "${DMG_PATH}"
hdiutil verify "${DMG_PATH}"

printf 'Built %s\n' "${DMG_PATH}"
printf 'Architectures: %s\n' "${ACTUAL_ARCHS}"
