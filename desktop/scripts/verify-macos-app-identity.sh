#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --configuration debug|profile|release [--app /path/to/app]" >&2
}

configuration=""
app_path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --configuration)
      configuration="${2:-}"
      shift 2
      ;;
    --app)
      app_path="${2:-}"
      shift 2
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
desktop_dir="$(cd "${script_dir}/.." && pwd)"

case "${configuration}" in
  debug)
    xcode_configuration="Debug"
    expected_name="Pi App Dev"
    expected_bundle_id="dev.pi.piDesktop.dev"
    expected_icon="AppIconDev"
    ;;
  profile)
    xcode_configuration="Profile"
    expected_name="Pi App Dev"
    expected_bundle_id="dev.pi.piDesktop.dev"
    expected_icon="AppIconDev"
    ;;
  release)
    xcode_configuration="Release"
    expected_name="Pi App"
    expected_bundle_id="dev.pi.piDesktop"
    expected_icon="AppIcon"
    ;;
  *)
    usage
    exit 1
    ;;
esac

if [[ -z "${app_path}" ]]; then
  app_path="${desktop_dir}/build/macos/Build/Products/${xcode_configuration}/${expected_name}.app"
fi

info_plist="${app_path}/Contents/Info.plist"
resources_dir="${app_path}/Contents/Resources"

if [[ ! -d "${app_path}" ]]; then
  echo "Expected ${configuration} app bundle is missing: ${app_path}" >&2
  exit 1
fi

if [[ ! -f "${info_plist}" ]]; then
  echo "Expected Info.plist is missing: ${info_plist}" >&2
  exit 1
fi

read_plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$1" "${info_plist}"
}

assert_plist_value() {
  local key="$1"
  local expected="$2"
  local actual
  actual="$(read_plist_value "${key}")"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "Expected ${key}=${expected}, found ${actual}." >&2
    exit 1
  fi
}

assert_plist_value "CFBundleName" "${expected_name}"
assert_plist_value "CFBundleIdentifier" "${expected_bundle_id}"
assert_plist_value "CFBundleIconFile" "${expected_icon}"
assert_plist_value "CFBundleExecutable" "${expected_name}"

if [[ ! -x "${app_path}/Contents/MacOS/${expected_name}" ]]; then
  echo "Expected executable is missing: ${app_path}/Contents/MacOS/${expected_name}" >&2
  exit 1
fi

if [[ ! -f "${resources_dir}/${expected_icon}.icns" ]]; then
  echo "Expected icon resource is missing: ${resources_dir}/${expected_icon}.icns" >&2
  exit 1
fi

printf 'Verified %s macOS app identity: %s (%s, %s)\n' \
  "${configuration}" \
  "${expected_name}" \
  "${expected_bundle_id}" \
  "${expected_icon}"
