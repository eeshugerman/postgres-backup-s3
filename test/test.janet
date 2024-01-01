(import sofa :as t)
(import sh)
(import csv)
(import spork/json)

(def postgres-container-name "postgres")
(def backup-service-container-name "backup-service")
(def postgres-user "postgres")
(def postgres-password "secret")
(def seed-database "paila")
(def s3-region "us-east-1")
(def s3-bucket "postgres-backup-s3-test")
(def s3-prefix "backup")

(def bootstrap-database "postgres")


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

(defn assert-test-db-populated []
  (let [rows (exec-sql :sql "SELECT count(1) from public.customer")]
    (assert (pos? (length rows)) "Not populated: table is empty")))

(defn- includes [arr val]
  (truthy? (find (fn [x] (= val x)) arr)))

(defn assert-test-db-dne []
  (let [rows (exec-sql :sql "\\l" :database "postgres")
        dbs (map (fn [db] (db :Name)) rows)]
    (assert (not (includes dbs seed-database)))))

(defn create-test-db []
  (print "Creating empty test database")
  (exec-sql :sql (string "CREATE DATABASE " seed-database ";")
            :database bootstrap-database))

(defn drop-test-db []
  (print "Dropping test database")
  (exec-sql :sql (string "DROP DATABASE IF EXISTS " seed-database ";")
            :database bootstrap-database)
  (assert-test-db-dne))

(defn populate-test-db []
  (print "Populating test database")
  (exec-sql :file "./seed-data/pagila/pagila-schema.sql")
  (assert-test-db-populated))

(defn s3-join-key [ & parts ]
  (string/join parts "/"))

(defn s3-join-prefix [ & parts ]
  (string (string/join parts "/") "/"))

(defn s3-list-backups []
  (as-> (sh/$< aws
               --no-cli-pager
               s3api list-objects
               --bucket ,s3-bucket
               --prefix ,s3-prefix) res
        (json/decode res true)
        (res :Contents)
        (map (fn [x] (x :Key)) res)))

# (defn s3-delete-backups []
#   (sh/$ aws s3 rm ,(s3-join-prefix s3-bucket s3-prefix)))

(defn backup []
  (print "Running backup")
  (sh/$ docker compose exec ,backup-service-container-name sh backup.sh))

(defn restore []
  (print "Running restore")
  (sh/$ docker compose exec ,backup-service-container-name sh restore.sh))

(defn export-env [env]
  (loop [[name val] :pairs env]
    (os/setenv name val)))

(defn full-test [postgres-version alpine-version]
  (let [base-env {"POSTGRES_CONTAINER_NAME" postgres-container-name
                  "BACKUP_SERVICE_CONTAINER_NAME" backup-service-container-name
                  "POSTGRES_USER" postgres-user
                  "POSTGRES_PASSWORD" postgres-password
                  "SEED_DATABASE" seed-database
                  "S3_REGION" s3-region
                  "S3_BUCKET" s3-bucket
                  "S3_PREFIX" s3-prefix}
        env (merge base-env
                   {"POSTGRES_VERSION" postgres-version
                    "ALPINE_VERSION" alpine-version})]

    # TODO: cleanup s3 (false negatives!)

    # setup
    (export-env env)
    (delete-services)
    (create-services)
    (create-test-db)
    (populate-test-db)

    # test
    (backup)
    (drop-test-db)
    (create-test-db) # restore needs it to already exist
    (restore)
    (assert-test-db-populated) # asserts there's actually data in the table

    # teardown
    (delete-services)))

(def version-pairs
  [{:postgres "12" :alpine "3.12"}
   {:postgres "13" :alpine "3.14"}
   {:postgres "14" :alpine "3.16"}
   {:postgres "15" :alpine "3.17"}
   {:postgres "16" :alpine "3.19"}])

(each {:postgres pg-version :alpine alpine-version} version-pairs
  (t/test (string/format "postgres v%s" pg-version)
    (full-test pg-version alpine-version)))

(t/run-tests)
