# Changelog

Each entry is one update of this template. Breaking changes are listed first.

## v0.4.18 (2026-11-24)

First release of the template.

- opendesk `v0.4.18` (`ghcr.io/useopendesk/opendesk@sha256:a2d63dac…`) and the realtime gateway `v0.4.18` (`ghcr.io/useopendesk/realtime@sha256:d1037d6a…`), pinned by tag and digest.
- Railway Postgres (with pgvector) for all data, a Railway Bucket for attachments and raw email.
- Deploy on Railway button in the README.
- The owner account is created on first boot from `ADMIN_EMAIL` and a generated `ADMIN_PASSWORD`, and made an instance admin; public sign-up is off.
