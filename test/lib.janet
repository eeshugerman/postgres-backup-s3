(import spork/path)
(def divider-heavy "================================================================================")
(def divider-light "--------------------------------------------------------------------------------")
(var tests :private @[])

(defn it "Defines a test" [description thunk]
  (array/push tests {:description description
                     :thunk thunk}))

(defn- report "Default reporter" [results]
  (print "FAILURES:")
  (loop [result :in results]
    (unless (result :passed)
      (print divider-light)
      (let [{:test {:description test-desc} :error err} result]
        (printf "* %s" test-desc)
        (printf "    %s" err))))

  (print divider-heavy)
  (print "SUMMARY:")
  (print divider-light)
  (let [num-total (length results)
        num-passed (sum (map (fn [res] (if (res :passed) 1 0)) results))
        num-failed (- num-total num-passed)]
    (printf "Total:    %i" num-total)
    (printf "Passing:  %i" num-passed)
    (printf "Failed:   %i" num-failed))
  (print divider-heavy))

# TODO: do better
(defn- is-repl? []
  (and (= "janet" (path/basename (dyn *executable*)))
       (all (fn [arg] (not= ".janet" (path/ext arg))) (dyn *args*))))

(defn run-tests "Runs all test cases" []
  (def results @[])
  (loop [test :in tests]
    (array/push results (try
                          (do
                            (apply (test :thunk))
                            (printf "* %s ✅" (test :description))
                            {:test test :passed true})
                          ([err]
                           (printf "* %s ❌" (test :description))
                           {:test test :passed false :error err}))))
  (print divider-heavy)
  (report results)
  (when (and (not (is-repl?))
             (some (fn [res] (not (res :passed))) results))
    (os/exit 1)))

(defn reset "Clear defined tests" []
  (set tests @[]))
