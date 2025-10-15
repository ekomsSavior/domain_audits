# header_audit

A Bash script to audit HTTP security headers of web targets. Produces colorized terminal output and a Markdown report.

## Features

- Checks for presence and values of key HTTP headers (HSTS, CSP, X-Frame-Options, etc.)  
- Generates a letter grade (A–F) based on header coverage  
- Outputs a Markdown report under `reports/`  
- Optional `nmap` header script integration  

## Installation & Setup

```bash
# Clone the repository
git clone https://github.com/ekomsSavior/header_audit.git
cd header_audit

# Make the script executable
chmod +x header_audit.sh

# (Optional) Install dependencies
#   - curl (typically pre-installed)
#   - nmap (for enhanced header script checks)
