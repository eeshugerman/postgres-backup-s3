(import testament :prefix "" :exit true)
(import sh)
(import csv)

(def bootstrap-database "postgres")

(def postgres-container-name "postgres")
(def backup-service-container-name "backup-service")
(def postgres-user "postgres")
(def postgres-password "secret")
(def seed-database "paila")

(def base-env
  {"POSTGRES_CONTAINER_NAME" postgres-container-name
   "BACKUP_SERVICE_CONTAINER_NAME" backup-service-container-name
   "POSTGRES_USER" postgres-user
   "POSTGRES_PASSWORD" postgres-password
   "SEED_DATABASE" seed-database})

(def version-pairs
  [{"POSTGRES_VERSION" "12" "ALPINE_VERSION" "3.12"}
   {"POSTGRES_VERSION" "13" "ALPINE_VERSION" "3.14"}
   {"POSTGRES_VERSION" "14" "ALPINE_VERSION" "3.16"}
   {"POSTGRES_VERSION" "15" "ALPINE_VERSION" "3.17"}
   # {"POSTGRES_VERSION" "16" "ALPINE_VERSION" "3.19"}
  ])

(defn export-env [env]
  (loop [[name val] :pairs env]
    (os/setenv name val)))

(defn create-services []
  (print "Creating services")
  (sh/$ docker compose --progress=plain up --build --detach))

(defn delete-services []
  (print "Deleting services")
  (sh/$ docker compose --progress=plain down))

(defn exec-sql [&keys {:sql sql :file file :database database}]
  (when (or (and sql file) (and (not sql) (not file)))
    (error "specify sql XOR file"))
  (let [stdin-cmd (if sql ~(echo ,sql) ~(cat ,file))
        data (sh/$< ;stdin-cmd |
                    docker exec -i ,postgres-container-name psql
                    --csv
                    --echo-errors
                    --variable ON_ERROR_STOP=1
                    --username ,postgres-user
                    --dbname ,(or database seed-database))]
    (csv/parse data true)))

(defn create-test-db []
  (print "Creating empty test database")
  (exec-sql :sql (string "CREATE DATABASE " seed-database ";")
            :database bootstrap-database))

(defn drop-test-db []
  (print "Dropping test database")
  (exec-sql :sql (string "DROP DATABASE IF EXISTS " seed-database ";")
            :database bootstrap-database))

(defn populate-test-db []
  (print "Populating test database")
  (exec-sql :file "./seed-data/pagila/pagila-schema.sql"))

(defn backup []
  (print "Running backup")
  (sh/$ docker compose exec ,backup-service-container-name sh backup.sh))

(defn restore []
  (print "Running restore")
  (sh/$ docker compose exec ,backup-service-container-name sh restore.sh))

(defn assert-test-db-populated []
  (let [rows (exec-sql :sql "SELECT count(1) from public.customer")]
    (is (pos? (length rows)) "Not populated: table is empty")))

(defn- includes [arr val]
  (reduce (fn [acc elem] (or acc (= elem val)))
          false
          arr))

(defn assert-test-db-dne []
  # TODO: make this do what the name says more directly
  (let [rows (exec-sql :sql "\\l" :database "postgres")
        dbs (map (fn [db] (db :Name)) rows)]
    (is (not (includes dbs seed-database)))))

(defn full-test [postgres-version alpine-version]
  (let [env (merge base-env { "POSTGRES_VERSION" postgres-version "ALPINE_VERSION" alpine-version})]
    (export-env env)
    (delete-services)
    (create-services)
    (create-test-db)
    (populate-test-db)
    (assert-test-db-populated)
    (backup)
    (drop-test-db)
    (assert-test-db-dne)
    (create-test-db) # restore needs it to already exist
    (restore)
    (assert-test-db-populated) # asserts there's actually data in the table
    (delete-services)
    ))

(deftest pg-12 (full-test "12" "3.12"))
(deftest pg-13 (full-test "13" "3.14"))
(deftest pg-14 (full-test "14" "3.16"))
(deftest pg-15 (full-test "14" "3.18"))

(run-tests!)

