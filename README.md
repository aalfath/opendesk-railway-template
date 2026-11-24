[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/opendesk?utm_medium=integration&utm_source=button&utm_campaign=opendesk)

# opendesk on Railway

One-click Railway template for [opendesk](https://github.com/useopendesk/opendesk), the open-source helpdesk: a shared inbox for email and live chat, assignments, a help center and an embeddable chat widget.

This repo pins opendesk **v0.4.18** (official images, by tag and digest) and is what every service of the template builds from.

## What the template deploys

| Service | Built from | What it does |
| --- | --- | --- |
| `opendesk` | `opendesk/` (pins `ghcr.io/useopendesk/opendesk:v0.4.18@sha256:a2d63dac…`) | API, background workers, web app, admin panel (`/admin/`) and an embedded NATS bus for the gateway. Public domain, health check `/readyz`. |
| `realtime` | `realtime/` (pins `ghcr.io/useopendesk/realtime:v0.4.18@sha256:d1037d6a…`) | Phoenix WebSocket gateway for live updates and the chat widget. Public domain, health check `/health`. Joins opendesk's NATS over the private network. |
| `Postgres` | Railway Postgres (has pgvector) | All tickets, conversations, users and background jobs. On a volume. |
| `Bucket` | Railway Bucket | Attachments and raw inbound email (S3-compatible, private, served by signed URLs). |

## After deploy

1. Open the `opendesk` service's public URL.
2. Sign in with `ADMIN_EMAIL` and the generated `ADMIN_PASSWORD` (Railway → `opendesk` → Variables). That account was created on first boot and is an instance admin; create your workspace when asked.
3. Public sign-up is closed (`SIGNUP_ENABLED=false`). Add teammates from **Settings → Members**: copy the invitation link and send it yourself (or set SMTP so opendesk emails it).
4. The admin panel at `/admin/` asks for two-factor authentication: turn it on first under **Settings → Security**.

## Variables

| Service | Variable | Default | Notes |
| --- | --- | --- | --- |
| opendesk | `ADMIN_EMAIL` | prompt | The owner account's email. |
| opendesk | `ADMIN_PASSWORD` | `${{secret(24)}}` | The owner's first password (change it in Settings). |
| opendesk | `AUTH_SECRET`, `CREDENTIALS_KEY`, `NATS_TOKEN`, `INBOUND_SECRET` | generated | Session signing, encryption of stored mailbox credentials (keep it!), gateway bus token, inbound-mail signing. |
| opendesk | `OPENDESK_URL`, `GATEWAY_URL` | Railway domains | Public URLs of opendesk and the gateway. |
| opendesk | `DATABASE_URL`, `S3_*` | references | Postgres and the Bucket. |
| realtime | `AUTH_SECRET`, `NATS_TOKEN`, `NATS_URL`, `CHECK_ORIGINS` | references | Shared with opendesk. |
| realtime | `SECRET_KEY_BASE` | generated | Phoenix secret. |

Optional, add them to `opendesk` when you need them:

- **Outgoing email** (notifications, invitations, password resets): `SMTP_HOST`, `SMTP_PORT` (587), `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_TLS` (`starttls`/`tls`), `MAIL_FROM`. Without `SMTP_HOST` mail is only written to the log. Mailboxes you connect over IMAP/SMTP, Google or Microsoft send their own replies.
- **AI** (reply drafts, triage, summaries): `ANTHROPIC_API_KEY`, or `OPENAI_API_KEY` (+ `OPENAI_BASE_URL`, `AI_MODEL` for any OpenAI-compatible API). No key = AI off.
- **Sign-in with Google/Microsoft/GitHub/OIDC**, Turnstile and more: see upstream's [configuration docs](https://docs.opendesk.sh/self-hosting/configuration/).

## Sizing

Fits Railway's Free plan limits (0.5 GB RAM per service, one volume plus one bucket). Tested on Railway with every service capped at 0.5 GB / 1 vCPU: opendesk peaked at about 295 MB with three 20 MB uploads at once, realtime idles at about 150 MB.

## Not included

- **Inbound SMTP** (the `smtp-inbound` profile): Railway has no public TCP port 25. Connect mailboxes over IMAP, Google or Microsoft, or forward mail instead.
- **Ollama** (local models): no GPU on Railway; use an API key instead.
- **Caddy** and **RustFS/MinIO** from upstream's compose file: Railway's edge terminates TLS, and the Railway Bucket replaces the S3 container.

## Updates

Railway tells everyone who deployed this template when this repo's `main` changes. Each update bumps the pinned images in `opendesk/Dockerfile` and `realtime/Dockerfile` and is described in [CHANGELOG.md](CHANGELOG.md), breaking changes first. Database migrations run automatically when opendesk starts. Back up Postgres before applying an update.

## Licence

opendesk is Apache-2.0 (© its authors). This wrapper is Apache-2.0 too.
