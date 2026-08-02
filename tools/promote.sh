#!/usr/bin/env bash
#
# promote.sh <name> [<name> ...]
#
# Refreshes one dataset in this repo from the Dropbox archive
# (~/Dropbox/data/<name>/), then recomputes its sha256s and byte counts in
# manifest.yml.
#
# The leak-guard: the ONLY files that move are the ones already declared in
# manifest.yml under that dataset. The archive is a workshop full of raw
# sources, replication archives, scratch scripts and exploratory output; none
# of it is promoted implicitly. To add a genuinely new file, add its `- path:`
# entry to manifest.yml first (sha256/bytes may be left as placeholders), then
# run this.
#
# This script only ever READS the archive. Back-propagation in the other
# direction is a separate, deliberate step.
#
#   ./tools/promote.sh returns
#   ARCHIVE_ROOT=/some/other/archive ./tools/promote.sh soc
#
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "${SELF_DIR}/lib/common.sh"

REPO_ROOT="$(cd "${SELF_DIR}/.." && pwd)"
MANIFEST="${REPO_ROOT}/manifest.yml"
: "${ARCHIVE_ROOT:=${HOME}/Dropbox/data}"
DRY_RUN="${DRY_RUN:-0}"

usage() { printf 'usage: %s <dataset-name> [<dataset-name> ...]\n' "$(basename "$0")" >&2; exit 2; }
[ $# -ge 1 ] || usage

RECORDS="$(mktemp "${TMPDIR:-/tmp}/td-records.XXXXXX")"
UPDATES="$(mktemp "${TMPDIR:-/tmp}/td-updates.XXXXXX")"
trap 'rm -f "$RECORDS" "$UPDATES"' EXIT
read_manifest "$MANIFEST" > "$RECORDS"
: > "$UPDATES"

for NAME in "$@"; do
  awk -F'\t' -v n="$NAME" '$1=="DS" && $2==n {found=1} END {exit !found}' "$RECORDS" \
    || die "no dataset '${NAME}' in manifest.yml -- add an entry before promoting"

  ARCHIVE_DIR="${ARCHIVE_ROOT}/${NAME}"
  [ -d "$ARCHIVE_DIR" ] || die "archive directory not found: ${ARCHIVE_DIR}"

  note "promoting ${NAME} from ${ARCHIVE_DIR}"
  declared=0
  missing=0

  while IFS=$'\t' read -r kind fname fpath _sha _pack; do
    [ "$kind" = "F" ] || continue
    [ "$fname" = "$NAME" ] || continue
    declared=$((declared + 1))

    rel="${fpath#data/${NAME}/}"
    src="${ARCHIVE_DIR}/${rel}"
    dst="${REPO_ROOT}/${fpath}"

    if [ ! -f "$src" ]; then
      printf '  MISSING in archive: %s (repo copy left untouched)\n' "$rel" >&2
      missing=$((missing + 1))
      continue
    fi

    if [ -f "$dst" ] && [ "$(sha256_of "$src")" = "$(sha256_of "$dst")" ]; then
      printf '  unchanged  %s\n' "$rel"
    elif [ "$DRY_RUN" = "1" ]; then
      printf '  would copy %s\n' "$rel"
      continue
    else
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      printf '  updated    %s\n' "$rel"
    fi

    printf '%s\t%s\t%s\n' "$fpath" "$(sha256_of "$dst")" "$(wc -c < "$dst" | tr -d ' ')" >> "$UPDATES"
  done < "$RECORDS"

  printf '  %d declared file(s), %d missing from the archive\n' "$declared" "$missing"

  # Anything in the archive that is not declared stays there, by design.
  undeclared=$(
    find "$ARCHIVE_DIR" -type f 2>/dev/null | while read -r f; do
      rel="${f#"${ARCHIVE_DIR}"/}"
      awk -F'\t' -v n="$NAME" -v p="data/${NAME}/${rel}" \
        '$1=="F" && $2==n && $3==p {found=1} END {exit !found}' "$RECORDS" || printf '%s\n' "$rel"
    done | wc -l | tr -d ' '
  )
  printf '  %s undeclared archive file(s) left in place (workshop material)\n' "$undeclared"
done

if [ "$DRY_RUN" = "1" ]; then
  note "DRY_RUN=1: manifest not rewritten"
  exit 0
fi

if [ ! -s "$UPDATES" ]; then
  note "nothing to record in the manifest"
  exit 0
fi

note "updating manifest.yml"
TMP_MANIFEST="$(mktemp "${TMPDIR:-/tmp}/td-manifest.XXXXXX")"
awk -v updates="$UPDATES" '
  BEGIN {
    while ((getline line < updates) > 0) {
      split(line, a, "\t"); sha[a[1]] = a[2]; nbytes[a[1]] = a[3]
    }
    close(updates)
  }
  /^      - path:/ {
    p = $0; sub(/^[^:]*:[ \t]*/, "", p); gsub(/"/, "", p); cur = p; print; next
  }
  /^        sha256:/ { if (cur in sha)     { print "        sha256: " sha[cur];  next } }
  /^        bytes:/  { if (cur in nbytes)  { print "        bytes: " nbytes[cur]; next } }
  { print }
' "$MANIFEST" > "$TMP_MANIFEST"

mv "$TMP_MANIFEST" "$MANIFEST"
note "done -- review 'git diff manifest.yml' and 'git status' before committing"
