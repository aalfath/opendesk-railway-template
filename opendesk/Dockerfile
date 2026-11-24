# opendesk API, workers, web app and embedded NATS, for Railway.
# Upstream image pinned by release tag and digest (from the v0.4.18 release's images.json).
FROM busybox:1.37.0-musl@sha256:f6a95d611e0a8780fabdb2aec43e31275b2720dfefa3e41b16835bfc42454478 AS busybox

FROM ghcr.io/useopendesk/opendesk:v0.4.18@sha256:a2d63dac51dcf5bee23ac08e2c337936302141dfd537df66769d01b08ce9411c
# The upstream image is distroless (no shell). A static BusyBox gives the start
# script a shell and lets `railway ssh` open one.
USER 0:0
COPY --from=busybox /bin/busybox /bin/busybox
RUN ["/bin/busybox", "sh", "-c", "/bin/busybox --install -s /bin"]
COPY --chmod=0755 start.sh /start.sh
USER 65532:65532
ENTRYPOINT ["/bin/sh", "/start.sh"]
