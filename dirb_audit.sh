#!/usr/bin/env bash
# dirb_audit.sh - interactive quick audit for one or more URLs
# Usage: ./dirb_audit.sh
set -euo pipefail

# Helpers
norm_url() {
  local u="$1"
  # If scheme missing, assume https
  if [[ ! "$u" =~ ^https?:// ]]; then
    u="https://$u"
  fi
  # strip trailing whitespace
  echo "$u"
}

prompt_targets() {
  echo -n "Enter target URLs separated by spaces, or a path to a file prefixed with @ (e.g. @targets.txt): "
  read -r input
  if [[ -z "$input" ]]; then
    echo "No input provided. Exiting."
    exit 1
  fi

  if [[ "${input:0:1}" == "@" ]]; then
    file="${input:1}"
    if [[ ! -f "$file" ]]; then
      echo "File not found: $file"
      exit 1
    fi
    mapfile -t raw_urls < "$file"
  else
    # split on spaces
    IFS=' ' read -r -a raw_urls <<< "$input"
  fi

  targets=()
  for r in "${raw_urls[@]}"; do
    # skip empty lines
    [[ -z "$r" ]] && continue
    targets+=("$(norm_url "$r")")
  done

  if [[ ${#targets[@]} -eq 0 ]]; then
    echo "No valid targets found. Exiting."
    exit 1
  fi
}

# Main
prompt_targets

outdir="reports/dirb_audit_$(date +%F_%H%M%S)"
mkdir -p "$outdir"

echo "Starting audit for ${#targets[@]} target(s). Artifacts: $outdir"

for u in "${targets[@]}"; do
  safe=$(echo "$u" | sed -E 's#https?://##; s#[/:]#_#g')
  echo
  echo "=== Auditing: $u ==="
  echo "Saving artifacts to: $outdir/${safe}_*"

  # 1) Headers (follow redirects)
  curl -I -L -s "$u" > "$outdir/${safe}_headers.txt" || true

  # 2) Full HTML
  curl -s -L "$u" -o "$outdir/${safe}.html" || true

  # 3) Extract assets (src/href)
  # Produce a list of assets (may include relative paths)
  grep -Eo '(src|href)=["'"'"']?([^"'"'"'> ]+)' "$outdir/${safe}.html" \
    | sed -E 's/^(src|href)=["'"'"']?//' \
    | sed -E 's/^\/\//https:\/\//; s/^[[:space:]]+//' \
    | sort -u > "$outdir/${safe}_assets_raw.txt" || true

  # Normalize asset URLs: convert root-relative to absolute using base host
  base="$(echo "$u" | sed -E 's#(https?://[^/]+).*#\1#')"
  > "$outdir/${safe}_assets.txt"
  while IFS= read -r asset; do
    [[ -z "$asset" ]] && continue
    # skip mailto and javascript:
    if echo "$asset" | grep -Ei '^mailto:|^javascript:' >/dev/null; then
      continue
    fi
    if [[ "$asset" =~ ^/ ]]; then
      echo "${base}${asset}" >> "$outdir/${safe}_assets.txt"
    elif [[ "$asset" =~ ^https?:// ]]; then
      echo "$asset" >> "$outdir/${safe}_assets.txt"
    else
      # relative path (./file or assets/file) -> make absolute relative to base path
      path_base="$(echo "$u" | sed -E 's#(https?://[^/]+).*#\1#')"
      echo "${path_base}/${asset}" >> "$outdir/${safe}_assets.txt"
    fi
  done < "$outdir/${safe}_assets_raw.txt" || true
  sort -u -o "$outdir/${safe}_assets.txt" "$outdir/${safe}_assets.txt" || true

  # 4) Fetch JS assets (only .js)
  while IFS= read -r asset; do
    [[ -z "$asset" ]] && continue
    if echo "$asset" | grep -Ei '\.js($|[?&])' >/dev/null 2>&1; then
      fname="$outdir/${safe}_$(basename "$asset" | sed 's/[^a-zA-Z0-9._-]/_/g')"
      echo "  fetching JS: $asset -> $(basename "$fname")"
      curl -s -L "$asset" -o "$fname" || true
    fi
  done < "$outdir/${safe}_assets.txt" || true

  # 5) Grep for sensitive-looking strings in saved HTML and JS
  echo "  scanning for possible secrets in artifacts..."
  grep -EInR --line-number "api[_-]?key|client[_-]?id|client[_-]?secret|access[_-]?token|password|passwd|secret|token|auth" \
    "$outdir/${safe}.html" "$outdir/${safe}"* 2>/dev/null || true

  # 6) Optional: whatweb fingerprint (if available)
  if command -v whatweb >/dev/null 2>&1; then
    whatweb -v "$u" > "$outdir/${safe}_whatweb.txt" 2>/dev/null || true
  fi

  # 7) Run header_audit.sh if script is present and executable
  if [[ -x ./header_audit.sh ]]; then
    echo "  running header_audit.sh for $u"
    ./header_audit.sh "$u" > "$outdir/${safe}_header_audit_console.txt" 2>&1 || true
  fi

  echo "Artifacts for $u saved to $outdir/"
done

echo
echo "Audit complete. Review $outdir for details."
