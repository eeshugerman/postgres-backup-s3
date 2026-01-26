#! /bin/sh

set -u # `-e` omitted intentionally, but i can't remember why exactly :'(
set -o pipefail

source ./env.sh

s3_uri_base="s3://${S3_BUCKET}/${S3_PREFIX}"

file_type=".dump.gz"

if [ $# -eq 1 ]; then
  timestamp="$1"
  key_suffix="${POSTGRES_DATABASE}_${timestamp}${file_type}"
  key_size=$(aws $aws_args s3 ls "${s3_uri_base}/${key_suffix}" | awk '{ print $3 }')
else
  echo "Finding latest backup..."
  latest_entry=$(
    aws $aws_args s3 ls "${s3_uri_base}/" \
      | awk -v db="${POSTGRES_DATABASE}_" '$4 ~ "^" db { print $4, $3 }' \
      | sort \
      | tail -n 1
  )
  key_suffix=$(printf "%s" "$latest_entry" | awk '{ print $1 }')
  key_size=$(printf "%s" "$latest_entry" | awk '{ print $2 }')
fi

if [ -z "${key_suffix:-}" ]; then
  echo "No backups found for ${POSTGRES_DATABASE} under ${s3_uri_base}."
  exit 1
fi

conn_opts="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d $POSTGRES_DATABASE"
admin_conn_opts="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER -d postgres"

echo "Ensuring database exists..."
db_exists=$(psql $admin_conn_opts -tAc "SELECT 1 FROM pg_database WHERE datname='${POSTGRES_DATABASE}'")
if [ "$db_exists" != "1" ]; then
  createdb -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" "$POSTGRES_DATABASE"
fi

echo "Fetching, decompressing, and restoring backup from S3..."
# Note: stdin restores don't support -j parallel jobs or directory format.
pv_args="-f"
if [ -n "${key_size:-}" ]; then
  pv_args="${pv_args} -s ${key_size}"
fi
aws $aws_args s3 cp "${s3_uri_base}/${key_suffix}" - \
  | pv $pv_args \
  | pigz -dc \
  | pg_restore $conn_opts --clean --if-exists

echo "Restore complete."
