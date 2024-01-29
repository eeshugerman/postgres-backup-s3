#! /bin/sh

set -u # `-e` omitted intentionally, but i can't remember why exactly :'(
set -o pipefail

source ./env.sh

s3_uri_base="s3://${S3_BUCKET}/${S3_PREFIX}"

if [ "$BACKUP_ALL" = "true" ]; then
  file_ext=".dump.gz"
else
  file_ext=".dump"
fi

if [ -z "$PASSPHRASE" ]; then
  file_type=$file_ext
else
  file_type="${file_ext}.gpg"
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
  gpg --decrypt --batch --passphrase "$PASSPHRASE" db$file_type > db$file_ext
  rm db$file_type
fi

conn_opts="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER"

if [ "$BACKUP_ALL" = "true" ]; then
  gunzip db.dump.gz
  echo "Restoring all databases..."
  psql -f db.dump $conn_opts
else
  echo "Restoring from backup..."
  pg_restore $conn_opts -d $POSTGRES_DATABASE --clean --if-exists db.dump
fi

rm db.dump

echo "Restore complete."
