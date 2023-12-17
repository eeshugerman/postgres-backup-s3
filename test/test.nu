# run-tests --threads=0

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


const DEFAULT_DATABASE = 'postgres'

const base_env = {
    POSTGRES_CONTAINER_NAME: "postgres",
    BACKUP_SERVICE_CONTAINER_NAME: "backup-service",
    POSTGRES_USER: "postgres",
    POSTGRES_PASSWORD: "secret",
    SEED_DATABASE: "pagila",
}


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
    # TODO: make this do what the name says more directly
    let rows = 'SELECT count(1) FROM public.customer;' | exec-sql
    assert (($rows | is-empty) or ($rows.count.0 == 0))
}

const version_pairs = [
    { POSTGRES_VERSION: '11', ALPINE_VERSION: '3.10' },
    { POSTGRES_VERSION: '12', ALPINE_VERSION: '3.12' },
    { POSTGRES_VERSION: '13', ALPINE_VERSION: '3.14' },
    { POSTGRES_VERSION: '14', ALPINE_VERSION: '3.16' },
    { POSTGRES_VERSION: '15', ALPINE_VERSION: '3.17' },
    { POSTGRES_VERSION: '16', ALPINE_VERSION: '3.19' },
]

def full-test [postgres_version: string alpine_version: string] {
    let full_env = $base_env | merge { POSTGRES_VERSION: $postgres_version, ALPINE_VERSION: $alpine_version };
    with-env $full_env {
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
}

#[test]
def test-pg-11 [] {
    full-test '11' '3.10'
}

#[test]
def test-pg-12 [] {
    full-test '12' '3.12'
}

#[test]
def test-pg-13 [] {
    full-test '13' '3.14'
}

#[test]
def test-pg-14 [] {
    full-test '14' '3.16'
}

#[test]
def test-pg-15 [] {
full-test '15' '3.17' # TODO: try 18
}

#[test]
def test-pg-16 [] {
    full-test '16' '3.19'
}
