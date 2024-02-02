ARG ALPINE_VERSION
FROM alpine:${ALPINE_VERSION}
ARG TARGETARCH

ENV GOROOT /usr/lib/go
ENV GOPATH /go
ENV PATH /go/bin:$PATH
ENV POSTGRES_DATABASE ''
ENV POSTGRES_HOST ''
ENV POSTGRES_PORT 5432
ENV POSTGRES_USER ''
ENV POSTGRES_PASSWORD ''
ENV PGDUMP_EXTRA_OPTS ''
ENV S3_ACCESS_KEY_ID ''
ENV S3_SECRET_ACCESS_KEY ''
ENV S3_BUCKET ''
ENV S3_REGION 'us-west-1'
ENV S3_PATH 'backups'
ENV S3_ENDPOINT ''
ENV CRON_SCHEDULE '* * * * *'
ENV PASSPHRASE ''
ENV BACKUP_RETENTION_IN_DAYS ''

RUN apk update && apk add --no-cache postgresql-client gnupg git s3cmd

ADD src/env.sh env.sh
ADD src/backup.sh backup.sh
ADD src/restore.sh restore.sh

RUN chmod +x env.sh backup.sh restore.sh

RUN echo "${CRON_SCHEDULE} cd / && ./backup.sh" >> /var/spool/cron/crontabs/root

CMD ["crond", "-f", "-d", "8"]
