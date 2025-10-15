domain_audits

A dual-script toolkit for auditing web domains and discovered endpoints.
Includes:
	•	header_audit.sh — checks HTTP security headers and grades configurations
	•	dirb_audit.sh — crawls and inspects endpoints, HTML, and JavaScript for quick reconnaissance

Features
	•	Run each module independently
	•	Saves all results in reports/
	•	Integrates automatically if both scripts are present
	•	Works entirely from Bash (no external requirements)

Installation

# Clone the repository
git clone
'''bash
https://github.com/ekomsSavior/domain_audits.git
cd domain_audits
'''
# Make scripts executable
chmod +x header_audit.sh
chmod +x dirb_audit.sh

Usage

1. Header Audit

Check a single domain for missing or weak HTTP headers and get an auto-grade.

./header_audit.sh https://target.com

Results are saved in reports/<domain>_headers.md.

2. Directory / Endpoint Audit

Interactively audit one or multiple URLs or a file list.

./dirb_audit.sh

When prompted:
	•	Enter one or more domains or URLs separated by spaces
	•	Or specify a file of targets using @filename.txt

Artifacts (headers, HTML, JS, fingerprints) are stored in reports/dirb_audit_<timestamp>/.

Notes
	•	Use responsibly on systems you own or have permission to test.
	•	Combine both modules for a complete surface and header security overview.
	•	Optional tools like whatweb enhance fingerprinting but are not required.
