#!/usr/bin/env bash
#
# fetch_data.sh <tag> <dest>
#
# Materializes one version of the course datasets into <dest>, which may be
# empty. Everything is pinned to <tag>: the tracked files and cards come from
# the tag's source tarball, the big datasets from that tag's release assets,
# and every delivered file is verified against the sha256 recorded in the
# tag's own manifest.yml -- which is also copied into <dest>/ so consumers
# (e.g. the Canvas label scan) can read `label:` locally.
#
# Repo coordinates and RESTRICTED_REPO are set in tools/lib/common.sh and can
# be overridden from the environment.
#
#   REPO_OWNER=someone ./fetch_data.sh v2026.08 ~/course/data-root
#
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# When run from a checkout, use the checkout's lib. When vendored alone, fall
# back to the lib inside the tarball we are about to download.
if [ -f "${SELF_DIR}/lib/common.sh" ]; then
  # shellcheck source=lib/common.sh
  . "${SELF_DIR}/lib/common.sh"
else
  : "${REPO_OWNER:=jaredsmurray}"
  : "${REPO_NAME:=teaching-data}"
  : "${REPO_URL:=https://github.com/${REPO_OWNER}/${REPO_NAME}}"
  : "${RESTRICTED_REPO:=${REPO_OWNER}/${REPO_NAME}}"
  die() { printf 'error: %s\n' "$*" >&2; exit 1; }
  note() { printf '>> %s\n' "$*"; }
  sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'
    else die "no sha256sum or shasum on PATH"; fi
  }
  MANIFEST_AWK=""
fi

usage() { printf 'usage: %s <tag> <dest>\n' "$(basename "$0")" >&2; exit 2; }

[ $# -eq 2 ] || usage
TAG="$1"
DEST="$2"

command -v curl >/dev/null 2>&1 || die "curl is required"
command -v unzip >/dev/null 2>&1 || die "unzip is required"

mkdir -p "$DEST"
DEST="$(cd "$DEST" && pwd)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/teaching-data.XXXXXX")"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

# --- 1. source tarball at the tag: tracked data, cards, manifest ------------
TARBALL="${REPO_URL}/archive/refs/tags/${TAG}.tar.gz"
note "fetching source tree at ${TAG}"
if ! curl -fsSL "$TARBALL" -o "${TMP}/src.tar.gz"; then
  die "could not download ${TARBALL} (is the tag pushed, and the repo public?)"
fi
mkdir -p "${TMP}/src"
tar -xzf "${TMP}/src.tar.gz" -C "${TMP}/src" --strip-components=1

SRC="${TMP}/src"
[ -f "${SRC}/manifest.yml" ] || die "tag ${TAG} has no manifest.yml"
if [ -z "${MANIFEST_AWK:-}" ] || [ ! -f "${MANIFEST_AWK}" ]; then
  MANIFEST_AWK="${SRC}/tools/lib/manifest.awk"
fi
[ -f "$MANIFEST_AWK" ] || die "manifest reader not found"

MANIFEST="${SRC}/manifest.yml"
awk -f "$MANIFEST_AWK" "$MANIFEST" > "${TMP}/records.tsv"

note "delivering cards and tracked datasets"
mkdir -p "${DEST}/cards"
if [ -d "${SRC}/cards" ]; then
  # cp -R of the directory contents; portable across GNU and BSD cp.
  find "${SRC}/cards" -type f -name '*.qmd' -exec cp {} "${DEST}/cards/" \;
fi
cp "$MANIFEST" "${DEST}/manifest.yml"

# --- 2. release zips for release-delivered datasets -------------------------
while IFS=$'\t' read -r kind name label delivery restricted asset _card; do
  [ "$kind" = "DS" ] || continue
  [ "$delivery" = "release-zip" ] || continue
  [ -n "$asset" ] || die "${name}: delivery is release-zip but no release_asset in manifest"

  if [ "$restricted" = "true" ]; then
    # Restricted assets are not anonymously downloadable. gh handles auth.
    command -v gh >/dev/null 2>&1 || die \
      "${name} is restricted; the GitHub CLI (gh), authenticated, is required. Set RESTRICTED_REPO to override the host repo."
    note "downloading restricted asset ${asset} from ${RESTRICTED_REPO} @ ${TAG}"
    gh release download "$TAG" --repo "$RESTRICTED_REPO" --pattern "$asset" --dir "$TMP" --clobber \
      || die "gh release download failed for ${asset}"
  else
    note "downloading ${asset} (${label})"
    curl -fsSL "${REPO_URL}/releases/download/${TAG}/${asset}" -o "${TMP}/${asset}" \
      || die "could not download release asset ${asset} for tag ${TAG}"
  fi

  unzip -q -o "${TMP}/${asset}" -d "$DEST"
done < "${TMP}/records.tsv"

# --- 3. tracked files, then unpack + verify every declared file -------------
fail=0
while IFS=$'\t' read -r kind name path sha packaged; do
  [ "$kind" = "F" ] || continue
  target="${DEST}/${path}"
  mkdir -p "$(dirname "$target")"

  if [ ! -f "$target" ]; then
    if [ -n "$packaged" ] && [ -f "${DEST}/$(dirname "$path")/${packaged}" ]; then
      # Distribution ships a compressed form; materialize the canonical name.
      pk="${DEST}/$(dirname "$path")/${packaged}"
      case "$packaged" in
        *.gz) note "gunzip ${packaged} -> $(basename "$path")"
              gunzip -c "$pk" > "$target" && rm -f "$pk" ;;
        *)    die "${path}: don't know how to unpack ${packaged}" ;;
      esac
    elif [ -f "${SRC}/${path}" ]; then
      cp "${SRC}/${path}" "$target"
    else
      printf 'MISSING  %s (%s)\n' "$path" "$name" >&2
      fail=1
      continue
    fi
  fi

  got="$(sha256_of "$target")"
  if [ "$got" != "$sha" ]; then
    printf 'SHA MISMATCH  %s\n  expected %s\n  got      %s\n' "$path" "$sha" "$got" >&2
    fail=1
  fi
done < "${TMP}/records.tsv"

[ "$fail" -eq 0 ] || die "verification failed; ${DEST} is not a trustworthy pin"

n=$(grep -c $'^F\t' "${TMP}/records.tsv" || true)
note "ok: ${n} files verified against manifest.yml @ ${TAG} in ${DEST}"
