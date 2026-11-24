#!/bin/sh
# Start script for opendesk on Railway.
#  1. Derives the public URLs and fixed settings from a few Railway variables.
#  2. On first boot, creates the owner account (ADMIN_EMAIL / ADMIN_PASSWORD) on a
#     loopback-only instance and makes it an instance admin, before the public port opens.
#  3. Runs opendesk with public sign-up closed (people join by invitation).
# Any failure exits non-zero so Railway restarts the service.
set -eu

log() { echo "[railway-start] $*"; }
die() { echo "[railway-start] ERROR: $*" >&2; exit 1; }

# ---- URLs -------------------------------------------------------------------
host_of() { echo "$1" | sed -E 's#^[a-z]+://##; s#/.*$##'; }
OPENDESK_URL="${OPENDESK_URL:-}"
[ -n "$(host_of "$OPENDESK_URL")" ] || die "OPENDESK_URL is empty: give the opendesk service a public domain and redeploy"
OPENDESK_URL="${OPENDESK_URL%/}"
export API_URL="${API_URL:-$OPENDESK_URL}"
export APP_URL="${APP_URL:-$OPENDESK_URL}"
export SITE_URL="${SITE_URL:-$OPENDESK_URL}"
export CORS_ORIGINS="${CORS_ORIGINS:-$OPENDESK_URL}"
if [ -z "$(host_of "${GATEWAY_URL:-}")" ]; then
  log "WARNING: GATEWAY_URL has no host (the realtime service has no public domain yet); live updates stay off until the next deploy"
  unset GATEWAY_URL
fi

# ---- Fixed settings -----------------------------------------------------------
export OPENDESK_ENV=production OPENDESK_ROLE=all SERVE_WEB=true DATA_DIR=/data
export SIGNUP_ENABLED="${SIGNUP_ENABLED:-false}"
# Railway's edge is the one proxy in front and appends the client to X-Forwarded-For.
export TRUSTED_PROXY_HOPS="${TRUSTED_PROXY_HOPS:-1}"
# Embedded NATS for the realtime gateway, on Railway's private network (IPv6 and IPv4).
export NATS_LISTEN="${NATS_LISTEN:-[::]:4222}"
[ -n "${NATS_TOKEN:-}" ] || die "NATS_TOKEN is empty"
# Attachments: the Railway Bucket when it is wired in, else local disk (lost on redeploy).
if [ -n "${S3_BUCKET:-}" ]; then
  export STORAGE_DRIVER="${STORAGE_DRIVER:-s3}" S3_REGION="${S3_REGION:-auto}"
else
  export STORAGE_DRIVER="${STORAGE_DRIVER:-local}"
  log "WARNING: no S3_BUCKET; attachments go to /data, which is not on a volume"
fi
# Outbound mail: SMTP as soon as SMTP_HOST is set, else mail is only logged.
if [ -n "${SMTP_HOST:-}" ]; then
  export MAIL_DRIVER="${MAIL_DRIVER:-smtp}" SMTP_PORT="${SMTP_PORT:-587}" SMTP_TLS="${SMTP_TLS:-starttls}"
else
  export MAIL_DRIVER="${MAIL_DRIVER:-log}"
fi
[ -n "${MAIL_FROM:-}" ] || export MAIL_FROM="opendesk <notifications@$(host_of "$OPENDESK_URL" | sed "s/:[0-9]*$//")>"
for v in SMTP_PORT SMTP_USERNAME SMTP_PASSWORD SMTP_HOST S3_ENDPOINT; do
  eval "val=\${$v:-}"; [ -n "$val" ] || unset "$v"
done
export PORT="${PORT:-8080}"
export HTTP_ADDR=":$PORT"

# Go sees every host CPU's memory as free: keep the heap inside the service's limit.
if [ -z "${GOMEMLIMIT:-}" ] && [ -r /sys/fs/cgroup/memory.max ]; then
  m=$(cat /sys/fs/cgroup/memory.max)
  if [ "$m" != "max" ]; then export GOMEMLIMIT="$(( m * 7 / 10 / 1048576 ))MiB"; fi
fi

# ---- First boot: the owner account -------------------------------------------
ADMIN_EMAIL="$(echo "${ADMIN_EMAIL:-}" | tr -d '[:space:]')"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"
[ -n "$ADMIN_EMAIL" ] || die "ADMIN_EMAIL is empty: set it to the email you will sign in with"
echo "$ADMIN_EMAIL" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$' || die "ADMIN_EMAIL is not a valid email address"
[ "${#ADMIN_PASSWORD}" -ge 12 ] || die "ADMIN_PASSWORD must be at least 12 characters"
case "$ADMIN_PASSWORD" in *[\"\\]*) die "ADMIN_PASSWORD must not contain quotes or backslashes";; esac

# Migrations first (idempotent, guarded by an advisory lock), retried while Postgres or
# its private DNS name is still coming up. Then the admin list tells first boot apart.
i=0
until /opendesk migrate >/tmp/migrate.log 2>&1; do
  i=$((i + 1))
  [ "$i" -lt 60 ] || { cat /tmp/migrate.log >&2; die "database not reachable after 3 minutes"; }
  [ "$i" -eq 1 ] && log "waiting for the database: $(tail -n 1 /tmp/migrate.log | cut -c1-160)"
  sleep 3
done
log "database ready, migrations applied"
export AUTO_MIGRATE=false
admins=$(/opendesk admin list) || die "could not list instance admins"
if echo "$admins" | grep -qiF "$ADMIN_EMAIL"; then
  log "owner $ADMIN_EMAIL already set up"
else
  log "first boot: creating the owner account on a loopback-only instance"
  BOOT_PORT=18080
  HTTP_ADDR="127.0.0.1:$BOOT_PORT" NATS_LISTEN="127.0.0.1:14222" SIGNUP_ENABLED=true OPENDESK_ROLE=api \
    UPDATE_CHECK=false /opendesk serve &
  boot_pid=$!
  i=0
  until wget -q -T 3 -O /dev/null "http://127.0.0.1:$BOOT_PORT/readyz" 2>/dev/null; do
    kill -0 "$boot_pid" 2>/dev/null || die "the bootstrap instance exited (see the log above)"
    i=$((i + 1)); [ "$i" -lt 120 ] || { kill "$boot_pid"; die "the bootstrap instance did not get ready in 120 s"; }
    sleep 1
  done
  body=$(printf '{"email":"%s","password":"%s","name":"Owner"}' "$ADMIN_EMAIL" "$ADMIN_PASSWORD")
  if wget -q -T 20 -O /dev/null --header 'Content-Type: application/json' --post-data "$body" \
       "http://127.0.0.1:$BOOT_PORT/v1/auth/register" 2>/dev/null; then
    log "owner account created"
  else
    log "register did not succeed (the account may already exist); checking with admin grant"
  fi
  kill "$boot_pid" 2>/dev/null || true
  wait "$boot_pid" 2>/dev/null || true
  # Fails when no account uses ADMIN_EMAIL, so a failed bootstrap stops the service.
  /opendesk admin grant "$ADMIN_EMAIL" || die "could not make $ADMIN_EMAIL an instance admin"
fi

log "starting opendesk on :$PORT (sign-up: $SIGNUP_ENABLED, storage: $STORAGE_DRIVER, mail: $MAIL_DRIVER)"
exec /opendesk serve
