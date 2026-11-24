#!/bin/sh
# Start script for the opendesk realtime gateway on Railway.
# Railway hosts show every CPU to the container, so the Erlang VM would start one
# scheduler per host CPU. Size them from the service's CPU limit instead.
set -eu
cpus=1
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read -r quota period < /sys/fs/cgroup/cpu.max || true
  if [ "${quota:-max}" != "max" ] && [ -n "${period:-}" ]; then
    cpus=$(( (quota + period - 1) / period ))
  else
    cpus=$(nproc 2>/dev/null || echo 2)
  fi
fi
[ "$cpus" -ge 1 ] || cpus=1
[ "$cpus" -le 8 ] || cpus=8
export ELIXIR_ERL_OPTIONS="${ELIXIR_ERL_OPTIONS:-} +S $cpus:$cpus +SDcpu $cpus:$cpus +SDio 2 +sbwt none +sbwtdcpu none +sbwtdio none"
export PORT="${PORT:-4000}"
# Railway's edge is the one proxy in front of the gateway.
export TRUSTED_PROXY_HOPS="${TRUSTED_PROXY_HOPS:-1}"
[ -n "${CHECK_ORIGINS:-}" ] && [ "${CHECK_ORIGINS%/}" != "https:" ] || { echo "CHECK_ORIGINS is empty: the opendesk service needs a public domain" >&2; exit 1; }
echo "[railway-start] realtime on :$PORT with $cpus scheduler(s)"
exec /app/bin/entrypoint "$@"
