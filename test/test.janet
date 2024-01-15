(import sofa :as t)
(import sh)
(import csv)
(import spork/json)

(def network-name "test-network")
(def postgres-container-name "postgres")
(def backup-service-container-name "backup-service")
(def postgres-user "postgres")
(def postgres-password "secret")
(def seed-database "paila")
(def s3-region "us-east-1")
(def s3-bucket "postgres-backup-s3-test")
(def s3-prefix "backup")

(def bootstrap-database "postgres")


(defn create-services [pg-version alpine-version options-env]

  (defn build-docker-env-flags [env]
    (reduce (fn [acc (key val)]
              [(splice acc) "--env" (string key "=" val)])
            []
            (pairs env)))

  (defn wait-for-postgres []
    (var attempts 0)
    (while true
      (let [[rc] (sh/run docker exec ,postgres-container-name pg_isready)
            ready (= 0 rc)]
        (set attempts (+ 1 attempts))
        (when ready
          (break))
        (when (> attempts 10)
          (error "Timed out waiting for Postgres to start")))
      (ev/sleep 1)))

  (print "Creating services")
  (let [backup-service-image-tag (string "postgres-backup-s3:" pg-version)
        postgres-image-tag (string "postgres:" pg-version)]

    (sh/$ docker build
          --progress plain
          --build-arg ,(string "ALPINE_VERSION=" alpine-version)
          --tag ,backup-service-image-tag
          "..")

    (sh/$ docker network create ,network-name)

    (sh/$ docker run
          --rm
          --network ,network-name
          --hostname ,postgres-container-name
          --name ,postgres-container-name
          ;(build-docker-env-flags
             {"POSTGRES_USER" postgres-user
              "POSTGRES_PASSWORD" postgres-password
              "POSTGRES_DATABASE" seed-database})
          --detach
          ,postgres-image-tag)

    (wait-for-postgres)

    (sh/$ docker run
          --rm
          --network ,network-name
          --name ,backup-service-container-name
          ;(build-docker-env-flags
             (merge {"POSTGRES_HOST" postgres-container-name
                     "POSTGRES_USER" postgres-user
                     "POSTGRES_PASSWORD" postgres-password
                     "POSTGRES_DATABASE" seed-database
                     "S3_REGION" s3-region
                     "S3_BUCKET" s3-bucket
                     "S3_PREFIX" s3-prefix
                     "S3_ACCESS_KEY_ID" (os/getenv "AWS_ACCESS_KEY_ID")
                     "S3_SECRET_ACCESS_KEY" (os/getenv "AWS_SECRET_ACCESS_KEY")
                     # prevent immediate exit
                     # instead, maybe we should start the container in `backup`
                     "SCHEDULE" "@yearly"}
                    options-env))
          --detach
          ,backup-service-image-tag)))

(defn is-service-up [container-name]
  # using json because otherwise header row is always present
  (-> (sh/$< docker ps --format json --filter ,(string "name=^" container-name "$"))
      (length)
      (> 0)))

(defn delete-services []
  (print "Deleting services")
  (each container-name [backup-service-container-name postgres-container-name]
    (when (is-service-up container-name)
      # we run start containers with --rm, so all we need to do here is stop it
      (sh/$ docker stop ,container-name)))
  # --force to ignore DNE
  (sh/$ docker network rm --force ,network-name))

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
  (let [rows (exec-sql :sql "SELECT count(1) FROM public.customer")]
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

(defn s3-join-key [& parts]
  (string/join parts "/"))

(defn s3-join-prefix [& parts]
  (string (string/join parts "/") "/"))

(defn s3-list-backups []
  (as-> (sh/$< aws
               --no-cli-pager
               s3api list-objects
               --bucket ,s3-bucket
               --prefix ,s3-prefix) results
        (json/decode results true)
        (or (results :Contents) @[])))

# (defn s3-get-latest-backup-key []
#   (reduce2 (fn []
#             )
#           (s3-list-backups)))

(defn s3-get-object [key]
  (let [temp-file-path (sh/$<_ mktemp)]
    (sh/$ aws
          --no-cli-pager
          s3api get-object
          --bucket ,s3-bucket
          --key ,key
          ,temp-file-path)
    temp-file-path))

(defn assert-backup-encrypted [s3-key]
  (let [temp-file-path (s3-get-object s3-key)
        gpg-exit-code (sh/run gpg
                              --decrypt
                              --batch
                              --passphrase "FIXME"
                              ,temp-file-path)]
    (assert (= 0 gpg-exit-code))))

(defn s3-delete-backups []
  (let [s3uri (string "s3://" (s3-join-prefix s3-bucket s3-prefix))]
    (sh/$ aws s3 rm --recursive ,s3uri)))

(defn backup []
  (print "Running backup")
  (sh/$ docker exec ,backup-service-container-name sh backup.sh))

(defn restore []
  (print "Running restore")
  (sh/$ docker exec ,backup-service-container-name sh restore.sh))

(def version-pairs
  [{:postgres "12" :alpine "3.12"}
   {:postgres "13" :alpine "3.14"}
   # {:postgres "14" :alpine "3.16"}
   # {:postgres "15" :alpine "3.18"}
   # {:postgres "16" :alpine "3.19"}
])

(defn full-test [&keys {:pg-version pg-version
                        :alpine-version alpine-version
                        :options-env options-env
                        :file-asserts file-asserts}]
  (let [base-env {"POSTGRES_CONTAINER_NAME" postgres-container-name
                  "BACKUP_SERVICE_CONTAINER_NAME" backup-service-container-name
                  "POSTGRES_USER" postgres-user
                  "POSTGRES_PASSWORD" postgres-password
                  "POSTGRES_DATABASE" seed-database
                  "S3_REGION" s3-region
                  "S3_BUCKET" s3-bucket
                  "S3_PREFIX" s3-prefix
                  "S3_ACCESS_KEY_ID" (os/getenv "AWS_ACCESS_KEY_ID")
                  "S3_SECRET_ACCESS_KEY" (os/getenv "AWS_SECRET_ACCESS_KEY")}
        env (merge base-env
                   {"POSTGRES_VERSION" pg-version
                    "ALPINE_VERSION" alpine-version})]

    # setup
    (create-services pg-version alpine-version {})
    (create-test-db)
    (populate-test-db)

    # test
    (backup)
    # TODO: file asserts here
    (drop-test-db)
    (create-test-db) # restore needs it to already exist
    (restore)
    (assert-test-db-populated) # asserts there's actually data in the table

    # teardown
    (delete-services)))

(t/before
  # cleanup in case previous execution was killed prematurely
  (delete-services))

(t/before-each
  (s3-delete-backups))

(each {:postgres pg-version :alpine alpine-version} version-pairs
  (t/section (string "postgres v" pg-version)
    (t/test "without passphrase"
      (full-test :pg-version pg-version
                 :alpine-version alpine-version))
    (t/test "with passphrase"
      (full-test :pg-version pg-version
                 :alpine-version alpine-version
                 :options-env {"PASSPHRASE" "supersecret"}))))

(t/after-each
  # cleanup in case of failure
  (delete-services))

(t/run-tests)
