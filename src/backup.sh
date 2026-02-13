#! /bin/sh

set -eu
set -o pipefail

source ./env.sh

echo "Creating backup of $POSTGRES_DATABASE database..."
pgdump_compression_args=""
if [ -n "${PGDUMP_COMPRESSION:-}" ]; then
  pgdump_compression_args="-Z ${PGDUMP_COMPRESSION}"
fi

timestamp=$(date +"%Y-%m-%dT%H:%M:%S")
s3_uri_base="s3://${S3_BUCKET}/${S3_PREFIX}/${POSTGRES_DATABASE}_${timestamp}.dump"

s3_uri="${s3_uri_base}.gz"

echo "Compressing and uploading backup to $S3_BUCKET..."
pg_dump --format=custom \
        -h $POSTGRES_HOST \
        -p $POSTGRES_PORT \
        -U $POSTGRES_USER \
        -d $POSTGRES_DATABASE \
        $pgdump_compression_args \
        $PGDUMP_EXTRA_OPTS \
        | pigz \
        | aws $aws_args s3 cp - "$s3_uri"

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
