
# PowerShell Enterprise Automation Library

**Enterprise-grade PowerShell scripts for automation, user management, system monitoring, and secure API integrations.**

## Key Features
- **Security & Compliance:** No hardcoded credentials, secure parameterization, audit logging, GDPR/SOX/HIPAA compliance.
- **User Management:** Bulk operations for Active Directory, Exchange, Jira, Confluence.
- **System Administration:** Monitoring, maintenance, backup, and security.
- **API Integrations:** Atlassian, Office 365, OpsGenie, and more.
- **Modern Structure:** Domain-organized folders for scripts, modules, docs, and tests.

## Usage
1. **Clone:** `git clone [repository-url]`
2. **Browse:** Scripts organized by domain in `scripts/`
3. **Run:** Use parameterized scripts, never hardcode credentials.
4. **Test:** Use `tests/` and `WhatIf` for safe validation.

## Security Guidelines
- Use `Get-Credential` or secure files for authentication.
- Validate all parameters.
- Log all operations for audit/compliance.
- Sanitize error messages.

## Folder Overview
- `core/` – Shared modules/functions
- `scripts/` – Main automation scripts by domain
- `docs/` – API references, guides, templates
- `tests/` – Unit and integration tests
- `data/` – Configs, logs, reports

For SCCM consolidation naming, keep the private local inventory in `data/SCCMSoftwareCollectionConsolidation.CanonicalMap.psd1` and start from the tracked generic template in `data/SCCMSoftwareCollectionConsolidation.CanonicalMap.template.psd1`. The private file is ignored by git so environment-specific software names stay local.

## API Reference
See `docs/api-references/` for PowerShell examples and authentication patterns.

## Change Management
All updates tracked in `CHANGELOG.md` with semantic versioning.

---

*For details, see individual script documentation or contact the maintainer.*
