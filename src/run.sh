#! /bin/sh

set -eu

if [ "$S3_S3V4" = "yes" ]; then
    aws configure set default.s3.signature_version s3v4
fi

if [ -z "$SCHEDULE" ]; then
  echo "You need to set the SCHEDULE environment variable."
else
  exec go-cron "$SCHEDULE" /bin/sh backup.sh
fi
