# opendesk realtime gateway (Phoenix Channels over WebSocket), for Railway.
# Upstream image pinned by release tag and digest (from the v0.4.18 release's images.json).
FROM ghcr.io/useopendesk/realtime:v0.4.18@sha256:d1037d6ada684e69c93bb1ef1be72f452ce835efc91597f1a38c5cde09afafc1
COPY --chmod=0755 start.sh /app/bin/railway-start
ENTRYPOINT ["/usr/bin/tini", "--", "/app/bin/railway-start"]
CMD ["start"]
