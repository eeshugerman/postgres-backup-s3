#! /bin/sh

set -eu
set -o pipefail

source ./env.sh
mkdir -p backups

echo "Backing up ${POSTGRES_DATABASE}..."

file_name="${POSTGRES_DATABASE}_$(date +"%Y-%m-%dT%H:%M:%S").dump"

echo "Starting..."
pg_dump --format=custom \
        -h $POSTGRES_HOST \
        -p $POSTGRES_PORT \
        -U $POSTGRES_USER \
        -d $POSTGRES_DATABASE \
        $PGDUMP_EXTRA_OPTS \
        > /backups/${file_name}
echo "Finished..."

if [ -n "$PASSPHRASE" ]; then
  echo "Encrypting..."
  gpg --symmetric --batch --passphrase "$PASSPHRASE" "/backups/${file_name}"
  rm "/backups/${file_name}"
  echo "Encryption complete!"
fi

if [ -n "$BACKUP_RETENTION_IN_DAYS" ]; then
  echo "Pruning backups older than ${BACKUP_RETENTION_IN_DAYS} days..."
  find /backups/* -mtime +$BACKUP_RETENTION_IN_DAYS -exec rm {} \;
fi

echo "Syncing local backups with S3..."

s3cmd sync --host=$S3_ENDPOINT --region=$S3_REGION --host-bucket=$S3_BUCKET \
  --no-mime-magic --no-preserve --progress --stats --verbose \
  /backups/ "s3://${S3_BUCKET}/${S3_PREFIX}/"

echo "Backup of ${POSTGRES_DATABASE} completed successfully!"
