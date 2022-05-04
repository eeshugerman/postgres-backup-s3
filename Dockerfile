ARG ALPINE_VERSION=3.15
FROM alpine:${ALPINE_VERSION}
SHELL [ "/bin/sh", "-cex" ]
RUN apk add --no-cache postgresql-client gnupg py3-pip curl; \
pip3 install awscli; \
curl -L https://github.com/odise/go-cron/releases/download/v0.0.6/go-cron-linux.gz | zcat > /usr/local/bin/go-cron; \
chmod u+x /usr/local/bin/go-cron; \
apk del curl; \
rm -rf /var/cache/apk/*

COPY src/ ./

ENTRYPOINT [ "/run.sh" ]
