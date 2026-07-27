#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PUBSPEC_PATH="${DESKTOP_DIR}/pubspec.yaml"
RELEASE_TAG="${1:-${RELEASE_TAG:-}}"

if [[ -z "${RELEASE_TAG}" ]]; then
  echo "Missing release tag. Pass it as the first argument or set RELEASE_TAG." >&2
  exit 1
fi

VERSION_SPEC="$(awk '/^version:[[:space:]]*/ { sub(/^version:[[:space:]]*/, ""); print; exit }' "${PUBSPEC_PATH}")"
if [[ -z "${VERSION_SPEC}" ]]; then
  echo "Could not read version from ${PUBSPEC_PATH}." >&2
  exit 1
fi

BUILD_NAME="${VERSION_SPEC%%+*}"
EXPECTED_TAG="v${BUILD_NAME}"

if [[ "${RELEASE_TAG}" != "${EXPECTED_TAG}" ]]; then
  echo "Release tag ${RELEASE_TAG} does not match desktop build name ${BUILD_NAME}. Expected ${EXPECTED_TAG}." >&2
  exit 1
fi

echo "Verified release tag ${RELEASE_TAG} matches desktop build name ${BUILD_NAME}."
