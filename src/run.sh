#! /bin/sh

set -eu

# not needed here but source anyway to fail fast (ie at startup,
# instead of at first backup) for any missing env vars
source ./env.sh

if [ "$S3_S3V4" = "yes" ]; then
  aws configure set default.s3.signature_version s3v4
fi

if [ -z "$SCHEDULE" ]; then
  sh backup.sh
else
  exec go-cron "$SCHEDULE" /bin/sh backup.sh
fi
