# Introduction
This project provides Docker images to periodically backup a PostgreSQL database to AWS S3, and to restore from the backup as needed.

# Credit where due
This repository is a fork and re-structuring of schickling's [postgres-backup-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-backup-s3) and [postgres-restore-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-restore-s3).

fork goals:
  - [x] dedicated repository
  - [x] automated builds
  - [x] support multiple PostgreSQL versions
  - [x] merge backup and restore images?
  - [x] support encrypted (password-protected) backups
  - [x] option to restore from specific backup by timestamp

other changes:
  - uses `pg_dump`'s `custom` format (see [docs](https://www.postgresql.org/docs/10/app-pgdump.html))
  - backup blobs and all schemas by default
  - recreate all database objects on restore
  - some env vars renamed
  - only scheduled backups supported, not ad-hoc


# Usage
## Backup
```yaml
postgres:
  image: postgres:11
  environment:
    POSTGRES_USER: user
    POSTGRES_PASSWORD: password

pg_backup_s3:
  image: eeshugerman/postgres-backup-s3:11
  environment:
    SCHEDULE: '@daily'
    PASSPHRASE: passphrase
    S3_REGION: region
    S3_ACCESS_KEY_ID: key
    S3_SECRET_ACCESS_KEY: secret
    S3_BUCKET: my-bucket
    S3_PREFIX: backup
    POSTGRES_DATABASE: dbname
    POSTGRES_USER: user
    POSTGRES_PASSWORD: password
```
- Images are tagged by the major PostgreSQL version they support: `9`, `10`, `11`, or `12`.
- The `SCHEDULE` variable determines backup frequency. See go-cron schedules documentation [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).
- If `PASSPHRASE` is provided, the backup will be encrypted using GPG.

## Restore
> **WARNING**: DATA LOSS! All database objects will be dropped and re-created.

### ... from latest backup
```sh
docker exec <container name> sh restore.sh
```
- If your bucket has more than a 1000 files, the latest may not be restored -- only one S3 `ls` command is used
- Your S3 prefix should only contain backups which you wish to restore -- 'latest' is determined based on unix sort with no filtering

### ... from specific backup
```sh
docker exec <container name> sh restore.sh <timestamp>
```
