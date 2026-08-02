#!/usr/bin/env bash
# Shared helpers for the teaching-data tools. Source, don't execute.

# --- repo coordinates -------------------------------------------------------
# Everything that names the GitHub side lives here. Override from the
# environment when working against a fork or a mirror.
: "${REPO_OWNER:=jaredsmurray}"
: "${REPO_NAME:=teaching-data}"
: "${REPO_URL:=https://github.com/${REPO_OWNER}/${REPO_NAME}}"

# Where restricted (non-public) release assets live. The plan has not yet
# settled how these are hosted -- a public repo cannot carry private release
# assets -- so this is a single overridable knob rather than a decision.
# It defaults to the main repo; point it at a private mirror when one exists.
: "${RESTRICTED_REPO:=${REPO_OWNER}/${REPO_NAME}}"

TD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_AWK="${TD_LIB_DIR}/manifest.awk"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
note() { printf '>> %s\n' "$*"; }

# sha256 of a file, hash only. macOS ships shasum; Linux ships sha256sum.
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    die "no sha256sum or shasum on PATH"
  fi
}

# read_manifest <manifest.yml> -> TSV records (see manifest.awk)
read_manifest() {
  [ -f "$1" ] || die "manifest not found: $1"
  awk -f "$MANIFEST_AWK" "$1"
}
