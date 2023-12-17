use assert

# def docker-compose-ps [] {
#     docker compose ps --format=json | split row "\n" | each { |l| $l | from json }
# }

# def docker-compose-all-up [] {
#     let results = docker-compose-ps
#     (($results | all { |row| $row.Status | str starts-with 'Up' }) and
#      (($results | length) > 0))
# }

def docker-compose-up [] {
    docker compose --progress=plain up --build --detach
}

def exec-sql [sql: string database: string = 'postgres'] {
    docker exec postgres psql --csv --username=postgres --dbname $database --command $sql | from csv
}

def seed [] {
    exec-psql 'DROP DATABASE IF EXISTS pagila;'
    exec-psql 'CREATE DATABASE pagila;'
    open ./seed-data/pagila/pagila-schema.sql
        | docker exec -i postgres psql --username postgres --dbname pagila
    open ./seed-data/pagila/pagila-data.sql
        | docker exec -i postgres psql --username postgres --dbname pagila
}

def restore [] {
    docker compose exec backup-service sh restore.sh
}

with-env { POSTGRES_VERSION: "15", ALPINE_VERSION: "3.17" } {
    docker-compose-up
    start-backup
}
