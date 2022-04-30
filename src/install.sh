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
curl -L https://github.com/ivoronin/go-cron/releases/download/v0.0.5/go-cron_0.0.5_linux_${1}.tar.gz -O
tar xvf go-cron_0.0.5_linux_${1}.tar.gz
rm go-cron_0.0.5_linux_${1}.tar.gz
mv go-cron /usr/local/bin/go-cron
chmod u+x /usr/local/bin/go-cron
apk del curl


# cleanup
rm -rf /var/cache/apk/*
