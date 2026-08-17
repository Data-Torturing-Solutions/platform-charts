# Shared backup utility image for every app's backup CronJob.
# docker build -t registry.digitalocean.com/rosetraviss/backup-sqlite:1 images/backup
# docker push registry.digitalocean.com/rosetraviss/backup-sqlite:1
# Rarely changes — tag with a small integer, not a git SHA, and bump by hand.

FROM alpine:3.20
RUN apk add --no-cache sqlite gzip rclone bash \
    && adduser -D -u 10001 backup
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/backup.sh
USER backup
ENTRYPOINT ["/usr/local/bin/backup.sh"]
