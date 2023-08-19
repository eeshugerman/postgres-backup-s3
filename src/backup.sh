#! /bin/sh

set -eu
set -o pipefail

source ./env.sh

if [ "$BACKUP_ALL" = "true" ]; then
  echo "Creating backup of all databases..."
  pg_dumpall --clean \
             -h $POSTGRES_HOST \
             -p $POSTGRES_PORT \
             -U $POSTGRES_USER \
             $PGDUMP_EXTRA_OPTS \
             > db.dump
else
  echo "Creating backup of $POSTGRES_DATABASE database..."
  pg_dump --format=custom \
          -h $POSTGRES_HOST \
          -p $POSTGRES_PORT \
          -U $POSTGRES_USER \
          -d $POSTGRES_DATABASE \
          $PGDUMP_EXTRA_OPTS \
          > db.dump
fi

timestamp=$(date +"%Y-%m-%dT%H:%M:%S")
s3_uri_base="s3://${S3_BUCKET}/${S3_PREFIX}/${POSTGRES_DATABASE}_${timestamp}.dump"

if [ -n "$PASSPHRASE" ]; then
  echo "Encrypting backup..."
  rm -f db.dump.gpg
  gpg --symmetric --batch --passphrase "$PASSPHRASE" db.dump
  rm db.dump
  local_file="db.dump.gpg"
  s3_uri="${s3_uri_base}.gpg"
else
  local_file="db.dump"
  s3_uri="$s3_uri_base"
fi

echo "Uploading backup to $S3_BUCKET..."
aws $aws_args s3 cp "$local_file" "$s3_uri"
rm "$local_file"

echo "Backup complete."

if [ -n "$BACKUP_KEEP_DAYS" ]; then
  sec=$((86400*BACKUP_KEEP_DAYS))
  date_from_remove=$(date -d "@$(($(date +%s) - sec))" +%Y-%m-%d)
  backups_query="Contents[?LastModified<='${date_from_remove} 00:00:00'].{Key: Key}"

  echo "Removing old backups from $S3_BUCKET..."
  aws $aws_args s3api list-objects \
    --bucket "${S3_BUCKET}" \
    --prefix "${S3_PREFIX}" \
    --query "${backups_query}" \
    --output text \
    | xargs -n1 -t -I 'KEY' aws $aws_args s3 rm s3://"${S3_BUCKET}"/'KEY'
  echo "Removal complete."
fi
