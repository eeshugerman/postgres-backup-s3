use assert
use std log

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


def exec-sql [--database: string ] {
    (
        docker exec -i $env.POSTGRES_CONTAINER_NAME psql
            --csv
            --echo-errors
            --variable ON_ERROR_STOP=1
            --username $env.POSTGRES_USER
            --dbname (if $database != null { $database } else { $env.SEED_DATABASE })
    ) | from csv
}

def create-services [] {
    log info "Creating services"
    docker compose --progress=plain up --build --detach
}
def delete-services [] {
    log info "Deleting services"
    docker compose --progress=plain down
}

def create-test-db [] {
    log info "Creating empty test database"
    $'CREATE DATABASE ($env.SEED_DATABASE);' | exec-sql --database $DEFAULT_DATABASE
}
def drop-test-db [] {
    log info "Dropping test database"
    $'DROP DATABASE IF EXISTS ($env.SEED_DATABASE);' | exec-sql --database $DEFAULT_DATABASE
}

def populate-test-db [] {
    log info "Populating test database"
    open ./seed-data/pagila/pagila-schema.sql | exec-sql
    open ./seed-data/pagila/pagila-data.sql   | exec-sql
}

def backup [] {
    log info "Running backup"
    docker compose exec backup-service sh backup.sh
}

def restore [] {
    log info "Running restore"
    docker compose exec backup-service sh restore.sh
}

def assert-test-db-populated [] {
    let rows = 'SELECT count(1) FROM public.customer;' | exec-sql
    assert (not ($rows | is-empty)) 'Not populated: failed to select from table'
    assert ($rows.count.0 > 0) 'Not populated: table is empty'
}

def assert-test-db-dne [] {
    # note may log a psql error (database pagila dne)
    let rows = 'SELECT count(1) FROM public.customer;' | exec-sql
    assert (($rows | is-empty) or ($rows.count.0 == 0))
}
with-env { POSTGRES_VERSION: "15", ALPINE_VERSION: "3.17" } {
    timeit {
        delete-services
        create-services
        create-test-db
        populate-test-db
        assert-test-db-populated
        backup
        drop-test-db
        assert-test-db-dne
        create-test-db # restore needs it to already exist
        restore
        assert-test-db-populated # asserts there's actually data in the table
        delete-services
    }
}
