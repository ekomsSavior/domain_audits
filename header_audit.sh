#!/usr/bin/env bash
# _    _ ______          _____  ______ _____     _____ _    _ ______ _____ _  __
#| |  | |  ____|   /\   |  __ \|  ____|  __ \   / ____| |  | |  ____/ ____| |/ /
#| |__| | |__     /  \  | |  | | |__  | |__) | | |    | |__| | |__ | |    | ' / 
#|  __  |  __|   / /\ \ | |  | |  __| |  _  /  | |    |  __  |  __|| |    |  <  
#| |  | | |____ / ____ \| |__| | |____| | \ \  | |____| |  | | |___| |____| . \ 
#|_|  |_|______/_/    \_\_____/|______|_|  \_\  \_____|_|  |_|______\_____|_|\_\
# Phish Hunter Pro — HTTP Security Header Auditor (Terminal + Markdown)
# Author: ekomsSavior / Team EVA
# Usage: ./header_audit.sh https://target.com
# Output: reports/<domain>_headers.md
set -e

# Colors
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
BOLD="\e[1m"
RESET="\e[0m"

target="$1"
if [[ -z "$target" ]]; then
  echo -e "${RED}Usage:${RESET} $0 https://domain.com"
  exit 1
fi

# normalize domain
domain=$(echo "$target" | sed -E 's#https?://##' | sed -E 's#/.*##')
report_dir="reports"
mkdir -p "$report_dir"
outfile="${report_dir}/${domain}_headers.md"

echo -e "${BOLD}${BLUE}
 _    _ ______          _____  ______ _____     _____ _    _ ______ _____ _  __
| |  | |  ____|   /\\   |  __ \\|  ____|  __ \\   / ____| |  | |  ____/ ____| |/ /
| |__| | |__     /  \\  | |  | | |__  | |__) | | |    | |__| | |__ | |    | ' / 
|  __  |  __|   / /\\ \\ | |  | |  __| |  _  /  | |    |  __  |  __|| |    |  <  
| |  | | |____ / ____ \\| |__| | |____| | \\ \\  | |____| |  | | |___| |____| . \\ 
|_|  |_|______/_/    \\_\\_____/|______|_|  \\_\\  \\_____|_|  |_|______\\_____|_|\\_\\
${RESET}
"

echo -e "${BOLD}Running header audit on:${RESET} $target"
echo -e "${BOLD}Report file:${RESET} $outfile"
echo " "

timestamp=$(date --rfc-3339=seconds)

# Run curl to get raw headers
raw_headers=$(curl -I -s -L "$target" || true)

# Save raw headers & nmap output to file
echo -e "# 🧠 Phish Hunter Pro — Security Header Audit\n" > "$outfile"
echo -e "Target: [$target]($target)\n" >> "$outfile"
echo -e "Scan Timestamp: $timestamp\n" >> "$outfile"

echo "## 🛰️ Raw Header Output" >> "$outfile"
echo '```' >> "$outfile"
echo "$raw_headers" >> "$outfile"
echo '```' >> "$outfile"

# Nmap header summary (if nmap exists)
echo -e "\n${BOLD}Running nmap http-security-headers script (requires nmap)${RESET}"
echo -e "### Nmap summary\n" >> "$outfile"
if command -v nmap >/dev/null 2>&1; then
  nmap_out=$(nmap --script http-security-headers -p 80,443 "$domain" 2>/dev/null || true)
  echo '```' >> "$outfile"
  echo "$nmap_out" >> "$outfile"
  echo '```' >> "$outfile"
else
  echo -e "${YELLOW}nmap not found - skipping nmap script checks.${RESET}"
  echo "_nmap not installed; install nmap to run enhanced checks._" >> "$outfile"
fi

# Baseline headers to check
headers=(
"Strict-Transport-Security"
"X-Frame-Options"
"X-Content-Type-Options"
"Referrer-Policy"
"Permissions-Policy"
"Cross-Origin-Opener-Policy"
"Cross-Origin-Embedder-Policy"
"Cross-Origin-Resource-Policy"
"Content-Security-Policy"
)

echo -e "\n${BOLD}Baseline header check:${RESET}"
# Prepare Markdown table
echo -e "\n## 🧩 Baseline Header Check\n" >> "$outfile"
echo "| Header | Present | Value |" >> "$outfile"
echo "|--------|:------:|-------|" >> "$outfile"

present_count=0
total=${#headers[@]}

for h in "${headers[@]}"; do
  value=$(echo "$raw_headers" | grep -i "^$h:" -m1 | cut -d: -f2- | sed 's/^[[:space:]]*//')
  if [[ -n "$value" ]]; then
    echo -e "${GREEN}✔${RESET} $h -> ${value}"
    echo "| $h | ✅ | $value |" >> "$outfile"
    ((present_count++))
  else
    echo -e "${RED}✘${RESET} $h -> ${YELLOW}MISSING${RESET}"
    echo "| $h | ❌ | — |" >> "$outfile"
  fi
done

# Extra checks
echo -e "\n${BOLD}Extra quick checks:${RESET}"

cors=$(echo "$raw_headers" | grep -i '^access-control-allow-origin:' | head -n1 | cut -d: -f2- | sed 's/^[[:space:]]*//')
if [[ -n "$cors" ]]; then
  if [[ "$cors" == "*" ]]; then
    echo -e "${RED}⚠️  CORS wildcard detected (Access-Control-Allow-Origin: *).${RESET}"
    echo -e "\n_CORS wildcard detected — review endpoints that return sensitive info._" >> "$outfile"
  else
    echo -e "${GREEN}ℹ️  CORS policy present:${RESET} $cors"
  fi
else
  echo -e "${YELLOW}ℹ️  No Access-Control-Allow-Origin header present.${RESET}"
fi

hsts=$(echo "$raw_headers" | grep -i '^strict-transport-security:' -m1 || true)
if [[ -n "$hsts" ]]; then
  echo -e "${GREEN}✔ HSTS present:${RESET} $(echo $hsts | cut -d: -f2- | sed 's/^[[:space:]]*//')"
else
  echo -e "${RED}✘ HSTS missing — add Strict-Transport-Security header.${RESET}"
  echo -e "\n_HSTS missing — browsers won't enforce HTTPS automatically. Consider adding:_\n\`Strict-Transport-Security: max-age=63072000; includeSubDomains; preload\`" >> "$outfile"
fi

server_hdr=$(echo "$raw_headers" | grep -i '^server:' -m1 | cut -d: -f2- | sed 's/^[[:space:]]*//')
if [[ -n "$server_hdr" ]]; then
  echo -e "${BLUE}Server header:${RESET} ${server_hdr}"
fi

# Auto-grade logic
score=$(( present_count * 100 / total ))
grade="F"
if (( score >= 90 )); then grade="A"
elif (( score >= 75 )); then grade="B"
elif (( score >= 60 )); then grade="C"
elif (( score >= 40 )); then grade="D"
else grade="F"
fi

if [[ "$grade" == "A" ]]; then
  grade_color="${GREEN}"
elif [[ "$grade" == "B" ]]; then
  grade_color="${BLUE}"
elif [[ "$grade" == "C" ]]; then
  grade_color="${YELLOW}"
else
  grade_color="${RED}"
fi

echo -e "\n${BOLD}Auto-grade:${RESET} ${grade_color}${grade}${RESET} — ${present_count}/${total} headers present (${score}%)."
echo -e "\n**Auto-grade:** ${grade} — ${present_count}/${total} headers present (${score}%)." >> "$outfile"

# Quick recommendations
echo -e "\n${BOLD}Top Recommendations (quick):${RESET}"
if [[ -z "$hsts" ]]; then
  echo -e "${RED}- Add HSTS: Strict-Transport-Security: max-age=63072000; includeSubDomains; preload${RESET}"
else
  echo -e "${GREEN}- HSTS looks configured.${RESET}"
fi
csp=$(echo "$raw_headers" | grep -i '^content-security-policy:' -m1 || true)
if [[ -z "$csp" ]]; then
  echo -e "${RED}- Add a Content-Security-Policy to mitigate XSS (start with report-only if needed).${RESET}"
else
  echo -e "${GREEN}- CSP present.${RESET}"
fi
if [[ "$cors" == "*" ]]; then
  echo -e "${RED}- Lock down CORS (avoid wildcard *). Only allow trusted origins.${RESET}"
fi
xfo=$(echo "$raw_headers" | grep -i '^x-frame-options:' -m1 || true)
if [[ -z "$xfo" ]]; then
  echo -e "${RED}- Add X-Frame-Options: DENY (or use CSP frame-ancestors).${RESET}"
else
  echo -e "${GREEN}- Frame protection present.${RESET}"
fi

# Markdown recommendations
echo -e "\n## ⚙️ Recommended Secure Values\n" >> "$outfile"
cat <<'EOT' >> "$outfile"
