# Overview
This project provides Docker containers to backup/restore a PostgreSQL database to/from AWS S3 (or a compatible service like DigitalOcean Spaces). Both one-off and periodic/scheduled backups are supported. 

# Credit where due
This repository is a fork and re-structuring of schickling's [postgres-backup-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-backup-s3) and [postgres-restore-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-restore-s3).

Fork goals:
  - [x] dedicated repository
  - [x] automated builds
  - [x] support multiple PostgreSQL versions
  - [ ] support encrypted (password-protected) backups
  - [x] merge backup and restore images?

-------

# Usage
## Backup
```yaml
postgres:
  image: postgres
  environment:
    POSTGRES_USER: user
    POSTGRES_PASSWORD: password

pgbackups3:
  image: eeshugerman/postgres-backup-s3
  environment:
    SCHEDULE: '@daily'
    S3_REGION: region
    S3_ACCESS_KEY_ID: key
    S3_SECRET_ACCESS_KEY: secret
    S3_BUCKET: my-bucket
    S3_PREFIX: backup
    POSTGRES_DATABASE: dbname
    POSTGRES_USER: user
    POSTGRES_PASSWORD: password
    POSTGRES_EXTRA_OPTS: '--schema=public --blobs'
```
### Notes
#### Periodic backups
The `SCHEDULE` variable is determines backup frequency. It is optional -- without it, the backup will run once at start up. More information about the scheduling can be found [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).

#### Docker
Docker Compose is by no means required, you can use plain ol' Docker too -- just set the required env vars with the `-e` flag.

## Restore
With the container running, 
```sh
docker exec <container name> sh restore.sh
```
