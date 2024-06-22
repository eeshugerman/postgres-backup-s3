#! /bin/sh

set -eux
set -o pipefail

apk update

# install tzdata
apk add --no-cache tzdata

# install pg_dump
apk add postgresql-client

# install gpg
apk add gnupg

apk add aws-cli

# install go-cron
apk add curl
curl --fail --retry 4 --retry-all-errors -L https://github.com/prodrigestivill/go-cron/releases/download/v0.0.10/go-cron-linux-$TARGETARCH-static.gz | zcat > /usr/local/bin/go-cron
chmod u+x /usr/local/bin/go-cron
apk del curl


# cleanup
rm -rf /var/cache/apk/*
