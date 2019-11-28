This is a fork and restructuring of schickling's [postgres-backup-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-backup-s3) and [postgres-restore-s3](https://github.com/schickling/dockerfiles/tree/master/postgres-restore-s3).

See [`backup/README.md`](/backup/README.md) and [`restore/README.md`](/restore/README.md) for further instructions.

Fork goals:
  - [x] dedicated repository
  - [x] automated builds
  - [x] support multiple PostgreSQL versions
  - [ ] support encrypted (password-protected) backups
  - [x] merge backup and restore images?

-------

# Usage
## Backup

### Docker
```sh
$ docker run \
    -e S3_ACCESS_KEY_ID=key \
    -e S3_SECRET_ACCESS_KEY=secret \
    -e S3_BUCKET=my-bucket \
    -e S3_PREFIX=backup \
    -e POSTGRES_DATABASE=dbname \
    -e POSTGRES_USER=user \
    -e POSTGRES_PASSWORD=password \
    -e POSTGRES_HOST=localhost \
    eeshugerman/postgres-backup-s3
```

### Docker Compose
```yaml
postgres:
  image: postgres
  environment:
    POSTGRES_USER: user
    POSTGRES_PASSWORD: password

pgbackups3:
  image: eeshugerman/postgres-backup-s3
  container_name: pg-backup
  links:
    - postgres
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

### Automatic Periodic Backups

You can additionally set the `SCHEDULE` environment variable like `-e SCHEDULE="@daily"` to run the backup automatically.

More information about the scheduling can be found [here](http://godoc.org/github.com/robfig/cron#hdr-Predefined_schedules).

## Restore
With the container running, 
```sh
docker exec <container name> sh restore.sh
```
