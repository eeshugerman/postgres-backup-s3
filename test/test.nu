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
$env.SEED_DATABASE = "pagila"

const DEFAULT_DATABASE = 'postgres'


def start-services [] {
    docker compose --progress=plain up --build --detach
}

def exec-sql [--database: string ] {
    # todo: throw on error
    (
        docker exec -i $env.POSTGRES_CONTAINER_NAME psql
            --csv
            --echo-errors
            --variable ON_ERROR_STOP=1
            --username ($env.POSTGRES_USER)
            --dbname (if ($database != null) { $database } else { $env.SEED_DATABASE } )
    ) | from csv
}

def create-seed-database [] {
    $'CREATE DATABASE ($env.SEED_DATABASE);' | exec-sql --database $DEFAULT_DATABASE
}
def wipe-seed [] {
    $'DROP DATABASE IF EXISTS ($env.SEED_DATABASE);' | exec-sql --database $DEFAULT_DATABASE
}

def seed [] {
    wipe-seed
    create-seed-database
    open ./seed-data/pagila/pagila-schema.sql | exec-sql
    open ./seed-data/pagila/pagila-data.sql   | exec-sql
}
def assert-populated [] {
    let rows = 'SELECT count(1) FROM public.customer;' | exec-sql
    assert (not ($rows | is-empty)) 'Not populated: failed to select from table'
    assert ($rows.count.0 > 0) 'Not populated: table is empty'
    }

def assert-not-populated [] {
    let rows = 'SELECT count(1) FROM public.customer;' | exec-sql
    assert (($rows | is-empty) or ($rows.count.0 == 0))
}

def backup [] {
    docker compose exec backup-service sh backup.sh
}

def restore [] {
    create-seed-database
    docker compose exec backup-service sh restore.sh
}

with-env { POSTGRES_VERSION: "15", ALPINE_VERSION: "3.17" } {
    start-services
    seed
    assert-populated
    backup
    wipe-seed
    assert-not-populated
    restore
    assert-populated
}
