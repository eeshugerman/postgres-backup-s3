#! /bin/sh

set -u # `-e` omitted intentionally, but i can't remember why exactly :'(
set -o pipefail

source ./env.sh

s3_uri_base="s3://${S3_BUCKET}/${S3_PREFIX}"

if [ -z "$PASSPHRASE" ]; then
  file_type=".dump"
else
  file_type=".dump.gpg"
fi

if [ $# -eq 1 ]; then
  timestamp="$1"
  key_suffix="${POSTGRES_DATABASE}_${timestamp}${file_type}"
else
  echo "Finding latest backup..."
  key_suffix=$(
    aws $aws_args s3 ls "${s3_uri_base}/${POSTGRES_DATABASE}" \
      | sort \
      | tail -n 1 \
      | awk '{ print $4 }'
  )
fi

echo "Fetching backup from S3..."
aws $aws_args s3 cp "${s3_uri_base}/${key_suffix}" "db${file_type}"

if [ -n "$PASSPHRASE" ]; then
  echo "Decrypting backup..."
  gpg --decrypt --batch --passphrase "$PASSPHRASE" db.dump.gpg > db.dump
  rm db.dump.gpg
fi

conn_opts="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DATABASE"

echo "Restoring from backup..."
pg_restore $conn_opts --clean --if-exists db.dump
rm db.dump

echo "Restore complete."
