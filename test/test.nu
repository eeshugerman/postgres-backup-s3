# $nu
# $$ use std testing run tests
# $$ run-tests --threads=0

use std log
use assert

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
    let exit_code = docker compose --progress=plain up --build --detach | complete | get exit_code
    assert ($exit_code == 0) "Failed to create/start services"
}

def delete-services [] {
    log info "Deleting services"
    let exit_code = docker compose --progress=plain down | complete | get exit_code
    assert ($exit_code == 0) "Failed to stop/delete services"
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
def pg-v11 [] {
    full-test '11' '3.10'
}

#[test]
def pg-v12 [] {
    full-test '12' '3.12'
}

#[test]
def pg-v13 [] {
    full-test '13' '3.14'
}

#[test]
def pg-v14 [] {
    full-test '14' '3.16'
}

#[test-only]
def pg-v15 [] {
    full-test '15' '3.17' # TODO: try 3.18
}

#[test]
def pg-v16 [] {
    full-test '16' '3.19'
}
