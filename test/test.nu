use assert

# def docker-compose-ps [] {
#     docker compose ps --format=json | split row "\n" | each { |l| $l | from json }
# }

# def docker-compose-all-up [] {
#     let results = docker-compose-ps
#     (($results | all { |row| $row.Status | str starts-with 'Up' }) and
#      (($results | length) > 0))
# }


$env.POSTGRES_CONTAINER_NAME = "postgres"
$env.BACKUP_SERVICE_CONTAINER_NAME = "backup-service"
$env.POSTGRES_USER = "postgres"
$env.POSTGRES_PASSWORD = "secret"
$env.POSTGRES_DATABASE = "postgres"


def docker-compose-up [] {
    docker compose --progress=plain up --build --detach
}

def exec-sql [--database: string] {
    (
        docker exec -i $env.POSTGRES_CONTAINER_NAME psql
            --csv
            --variable ON_ERROR_STOP=1
            --username ($env.POSTGRES_USER)
            --dbname (if ($database != null) { $database } else { $env.POSTGRES_DATABASE } )
            ) | from csv
}

def seed [] {
    const database = 'pagila'
    $'DROP DATABASE IF EXISTS ($database);' | exec-sql
    $'CREATE DATABASE ($database);'         | exec-sql
    open ./seed-data/pagila/pagila-schema.sql | exec-sql --database $database
    open ./seed-data/pagila/pagila-data.sql   | exec-sql --database $database
}

def restore [] {
    docker compose exec backup-service sh restore.sh
}

with-env { POSTGRES_VERSION: "15", ALPINE_VERSION: "3.17" } {
    docker-compose-up
    seed
}
