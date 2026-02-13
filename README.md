# Introduction

This is a blatant fork of https://github.com/eeshugerman/postgres-backup-s3 which was itself a fork and re-structuring of @schickling's [postgres-backup-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-backup-s3) and [postgres-restore-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-restore-s3).

It was archived and I still relied on it. Plus I needed PG 18.

# Building the image

Obviously replace `miharekar` with your dockerhub username and `18.0` with the desired PostgreSQL version.

```
❯ docker build -t miharekar/postgres-backup-s3:18.0 --build-arg POSTGRES_VERSION='18.0' . && docker push miharekar/postgres-backup-s3:18.0
```

# Usage
## Backup
```yaml
services:
  backup:
    image: miharekar/postgres-backup-s3:18.0
    environment:
      SCHEDULE: '@weekly'     # optional
      BACKUP_KEEP_DAYS: 7     # optional
      PASSPHRASE: passphrase  # optional
      S3_REGION: region
      S3_ACCESS_KEY_ID: key
      S3_SECRET_ACCESS_KEY: secret
      S3_BUCKET: my-bucket
      S3_PREFIX: backup
      POSTGRES_HOST: postgres
      POSTGRES_DATABASE: dbname
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      PGDUMP_COMPRESSION: 0 # optional, default 0
      PGDUMP_EXTRA_OPTS: ""  # optional
```

- The `SCHEDULE` variable determines backup frequency. See go-cron schedules documentation [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules). Omit to run the backup immediately and then exit.
- `PGDUMP_COMPRESSION` controls `pg_dump -Z` compression; `0` disables compression (fastest, larger upload).
- Backups are streamed directly to S3 and do not require free local disk equal to dump size.
- Encryption via `PASSPHRASE` is no longer supported.
- Run `docker exec <container name> sh backup.sh` to trigger a backup ad-hoc.
- If `BACKUP_KEEP_DAYS` is set, backups older than this many days will be deleted from S3.
- Set `S3_ENDPOINT` if you're using a non-AWS S3-compatible storage provider.

## Restore
> [!CAUTION]
> DATA LOSS! All database objects will be dropped and re-created.

### ... from latest backup
```sh
docker exec <container name> sh restore.sh
```

> [!NOTE]
> If your bucket has more than a 1000 files, the latest may not be restored -- only one S3 `ls` command is used

### ... from specific backup
```sh
docker exec <container name> sh restore.sh <timestamp>
```

# Acknowledgements

As mentioned above, this project is a blatant fork of https://github.com/eeshugerman/postgres-backup-s3

As is the following text documenting the changes from the @schickling's [postgres-backup-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-backup-s3):

  - dedicated repository
  - automated builds
  - support multiple PostgreSQL versions
  - backup and restore with one image
  - some environment variables renamed or removed
  - uses `pg_dump`'s `custom` format (see [docs](https://www.postgresql.org/docs/10/app-pgdump.html))
  - drop and re-create all database objects on restore
  - backup blobs and all schemas by default
  - no Python 2 dependencies
  - filter backups on S3 by database name
  - support encrypted (password-protected) backups
  - support for restoring from a specific backup by timestamp
  - support for auto-removal of old backups

What's new in my fork is solely support for later versions of PostgreSQL.
