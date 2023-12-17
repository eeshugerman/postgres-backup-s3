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
    docker compose --progress=plain up --detach
}

def start-backup [] {
    docker compose exec backup sh /backup.sh
}

with-env { POSTGRES_VERSION: "15", ALPINE_VERSION: "3.17" } {
    docker-compose-up
    start-backup
}
