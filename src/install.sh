#! /bin/sh

set -eux
set -o pipefail

apk update

# install pg_dump
apk add postgresql-client

# install gpg
apk add gnupg

apk add python3
apk add py3-pip  # separate package on edge only
pip3 install awscli

# install go-cron
apk add curl
curl -L https://github.com/odise/go-cron/releases/download/v0.0.6/go-cron-linux.gz | zcat > /usr/local/bin/go-cron
chmod u+x /usr/local/bin/go-cron
apk del curl


# cleanup
rm -rf /var/cache/apk/*
