# Minimal reader for teaching-data's manifest.yml.
#
# The manifest has a fixed, machine-generated shape (2-space dataset keys,
# 4-space scalar fields, 6-space "- path:" file entries), so a full YAML
# parser is not needed -- and deliberately not required, since fetch_data.sh
# must run on a bare machine with nothing but coreutils, curl and awk.
#
# Emits tab-separated records:
#   DS    <name> <label> <delivery> <restricted> <release_asset> <card>
#   F     <name> <path>  <sha256>   <packaged_as>
# packaged_as is empty when the file ships under its canonical name.

function unquote(s) {
  sub(/^[ \t]+/, "", s)
  sub(/[ \t]+$/, "", s)
  if (s ~ /^".*"$/) { s = substr(s, 2, length(s) - 2); gsub(/\\"/, "\"", s) }
  return s
}

function value(line,   v) { v = line; sub(/^[^:]*:[ \t]*/, "", v); return unquote(v) }

function flush_file() {
  if (fpath != "") printf "F\t%s\t%s\t%s\t%s\n", ds, fpath, fsha, fpack
  fpath = ""; fsha = ""; fpack = ""
}

function flush_ds() {
  if (ds != "") printf "DS\t%s\t%s\t%s\t%s\t%s\t%s\n", ds, label, delivery, restricted, asset, card
  ds = ""; label = ""; delivery = ""; restricted = ""; asset = ""; card = ""
}

/^[ \t]*#/ { next }

/^  [A-Za-z0-9_.-]+:[ \t]*$/ {
  flush_file(); flush_ds()
  ds = $0; sub(/^  /, "", ds); sub(/:[ \t]*$/, "", ds)
  next
}

/^    label:/         { label = value($0); next }
/^    card:/          { card = value($0); next }
/^    delivery:/      { delivery = value($0); next }
/^    restricted:/    { restricted = value($0); next }
/^    release_asset:/ { asset = value($0); next }

/^      - path:/      { flush_file(); fpath = value($0); next }
/^        sha256:/    { fsha = value($0); next }
/^        packaged_as:/ { fpack = value($0); next }

END { flush_file(); flush_ds() }
