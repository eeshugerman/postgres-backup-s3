#! /bin/sh

set -eu

if [ "$S3_S3V4" = "yes" ]; then
    aws configure set default.s3.signature_version s3v4
fi

if [ -z "$SCHEDULE" ]; then
    # TODO: how to make CTRL-C work?
    echo "WARNING: $SCHEDULE is null. Going to sleep."
    tail -f /dev/null # do nothing forever
else
  exec go-cron "$SCHEDULE" /bin/sh backup.sh
fi
