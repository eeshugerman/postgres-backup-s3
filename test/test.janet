(import testament :prefix "" :exit true)
(import sh)

(deftest two-plus-two
  (is (= 5 (+ 2 2)) "2 + 2 = 5"))

(deftest one-plus-one
  (is (= 2 (+ 1 1)) "1 + 1 = 2"))

(deftest echo-hi-pass
  (assert-equal (string/trim (sh/$< echo "hi")) "hi"))

(deftest echo-hi-fail
  (assert-equal (string/trim (sh/$< echo "hi")) "bye"))

(run-tests!)

