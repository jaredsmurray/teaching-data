#!/usr/bin/env bash
#
# make_release.sh <tag>
#
# Builds the release assets for a data version: one zip per dataset whose
# manifest entry says `delivery: release-zip`, plus a SHA256SUMS file. It
# then PRINTS the `gh release create` command with every asset attached --
# it does not run it. Cutting and uploading the release is a deliberate,
# human step, and restricted assets may not belong on the public repo at all.
#
# Zips are built from the local working tree (the same files the manifest
# describes) and are laid out so that unzipping at a destination root
# reproduces the canonical `data/<name>/...` paths.
#
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SELF_DIR}/lib/common.sh"

REPO_ROOT="$(cd "${SELF_DIR}/.." && pwd)"
MANIFEST="${REPO_ROOT}/manifest.yml"

usage() { printf 'usage: %s <tag>\n' "$(basename "$0")" >&2; exit 2; }
[ $# -eq 1 ] || usage
TAG="$1"

command -v zip >/dev/null 2>&1 || die "zip is required"

OUT="${REPO_ROOT}/release/${TAG}"
rm -rf "$OUT"
mkdir -p "$OUT"

RECORDS="$(mktemp "${TMPDIR:-/tmp}/td-records.XXXXXX")"
trap 'rm -f "$RECORDS"' EXIT
read_manifest "$MANIFEST" > "$RECORDS"

assets=()
restricted_assets=()

while IFS=$'\t' read -r kind name label delivery restricted asset _card; do
  [ "$kind" = "DS" ] || continue
  [ "$delivery" = "release-zip" ] || continue
  [ -n "$asset" ] || die "${name}: release-zip with no release_asset in manifest"

  note "packing ${name} (${label})"
  STAGE="$(mktemp -d "${TMPDIR:-/tmp}/td-stage.XXXXXX")"

  while IFS=$'\t' read -r fkind fname fpath _fsha fpack; do
    [ "$fkind" = "F" ] || continue
    [ "$fname" = "$name" ] || continue
    src="${REPO_ROOT}/${fpath}"
    [ -f "$src" ] || die "${fpath} declared in manifest but missing from the working tree"
    mkdir -p "${STAGE}/$(dirname "$fpath")"
    if [ -n "$fpack" ]; then
      case "$fpack" in
        *.gz) gzip -c "$src" > "${STAGE}/$(dirname "$fpath")/${fpack}" ;;
        *)    die "${fpath}: don't know how to pack as ${fpack}" ;;
      esac
    else
      cp "$src" "${STAGE}/${fpath}"
    fi
  done < "$RECORDS"

  ( cd "$STAGE" && zip -q -r -X "${OUT}/${asset}" data )
  rm -rf "$STAGE"

  assets+=("${OUT}/${asset}")
  if [ "$restricted" = "true" ]; then
    restricted_assets+=("$asset")
  fi
done < "$RECORDS"

[ "${#assets[@]}" -gt 0 ] || die "no release-delivered datasets in the manifest"

( cd "$OUT" && for a in *.zip; do printf '%s  %s\n' "$(sha256_of "$a")" "$a"; done ) > "${OUT}/SHA256SUMS"

printf '\n'
note "assets in ${OUT}:"
( cd "$OUT" && ls -lh . | sed '1d' )
printf '\n'
cat "${OUT}/SHA256SUMS"
printf '\n'

if [ "${#restricted_assets[@]}" -gt 0 ]; then
  cat <<EOF
NOTE: these assets are marked restricted: true in manifest.yml --
  ${restricted_assets[*]}
A public repository cannot carry private release assets. Decide where they are
hosted before uploading; fetch_data.sh pulls restricted assets with
\`gh release download\` from \$RESTRICTED_REPO (currently ${RESTRICTED_REPO}).

EOF
fi

printf 'Run this yourself when you are ready to publish %s:\n\n' "$TAG"
printf 'gh release create %s \\\n' "$TAG"
printf '  --repo %s/%s \\\n' "$REPO_OWNER" "$REPO_NAME"
printf '  --title "%s" \\\n' "$TAG"
printf '  --notes "Course datasets, version %s." \\\n' "$TAG"
for a in "${assets[@]}"; do
  printf '  %s \\\n' "$a"
done
printf '  %s\n\n' "${OUT}/SHA256SUMS"
