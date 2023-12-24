(import testament :prefix "" :exit true)
(import sh)
(import csv)

(def bootstrap-database "postgres")

(def base-env
  @{"POSTGRES_CONTAINER_NAME" "postgres"
    "BACKUP_SERVICE_CONTAINER_NAME" "backup-service"
    "POSTGRES_USER" "postgres"
    "POSTGRES_PASSWORD" "secret"
    "SEED_DATABASE" "pagila"})

(def version-pairs
  [@{"POSTGRES_VERSION" "12" "ALPINE_VERSION" "3.12"}
   @{"POSTGRES_VERSION" "13" "ALPINE_VERSION" "3.14"}
   @{"POSTGRES_VERSION" "14" "ALPINE_VERSION" "3.16"}
   @{"POSTGRES_VERSION" "15" "ALPINE_VERSION" "3.17"}
   @{"POSTGRES_VERSION" "16" "ALPINE_VERSION" "3.19"}])

(defn export-env [env]
  (loop [[name val] :pairs env]
    (os/setenv name val)))

(defn create-services []
  (print "Creating services")
  (sh/$ docker compose --progress=plain up --build --detach))

(defn delete-services []
  (print "Deleting services")
  (sh/$ docker compose --progress=plain down))

(defn exec-sql [sql &opt database]
  (default database (os/getenv "SEED_DATABASE"))
  (let [data (sh/$< echo ,sql | docker exec -i ,(os/getenv "POSTGRES_CONTAINER_NAME") psql
                    --csv
                    --echo-errors
                    --variable ON_ERROR_STOP=1
                    --username ,(os/getenv "POSTGRES_USER")
                    --dbname ,database)]
    (csv/parse data true)))

(deftest two-plus-two
  (is (= 5 (+ 2 2)) "2 + 2 = 5"))

(deftest one-plus-one
  (is (= 2 (+ 1 1)) "1 + 1 = 2"))

(deftest echo-hi-pass
  (assert-equal (string/trim (sh/$< echo "hi")) "hi"))

(deftest echo-hi-fail
  (assert-equal (string/trim (sh/$< echo "hi")) "bye"))

# (run-tests!)

