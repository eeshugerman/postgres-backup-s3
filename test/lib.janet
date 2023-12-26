(import spork/path)
(import spork/generators)

(def divider-heavy "================================================================================")
(def divider-light "--------------------------------------------------------------------------------")

# no reason to use a dynamic binding here since it's global anyway (?)
(def toplevel :private @[])

(defn group [description thunk]
  (with-dyns [:children @[]
              :before nil
              :before-each nil
              :after nil
              :after-each nil]
    (thunk)
    (array/push toplevel {:type 'group
                          :description description
                          :children (dyn :children)
                          :before (dyn :before)
                          :before-each (dyn :before-each)
                          :after (dyn :after)
                          :after-each (dyn :after-each)})))

(defn before [thunk]
  (setdyn :before thunk))

(defn before-each [thunk]
  (setdyn :before-each thunk))

(defn after [thunk]
  (setdyn :after thunk))

(defn after-each [thunk]
  (setdyn :after-each thunk))

(defn test [description thunk]
  (array/push (dyn :children) {:type 'test
                               :description description
                               :thunk thunk}))

(defn execute-toplevel []
  (map (fn [group]
         # TODO: catch errors in hooks?
         (when-let [before (group :before)]
           (before))
         (def child-results
           (map (fn [child]
                  (when-let [before-each (group :before-each)]
                    (before-each))
                  (match child
                    {:type 'test :thunk thunk :description desc}
                    (try
                      (do
                        ((test :thunk))
                        (printf "* %s ✅" (test :description))
                        {:type 'test :test test :passed true})
                      ([err]
                       (printf "* %s ❌" (test :description))
                       {:type 'test :test test :passed false :error err}))
                    # TODO: :type 'group
                    )
                  (when-let [after-each (group :after-each)]
                    (after-each)))
                (group :children)))
         (when-let [after (group :after)]
           (after))
         {:type 'group :group group :children child-results})
       toplevel))

(defn run-tests []
  (def results (execute-toplevel))
  (print divider-heavy)
  (report results)
  (let
      # TODO: do better
      [is-repl (and (= "janet" (path/basename (dyn *executable*)))
                    (all (fn [arg] (not= ".janet" (path/ext arg))) (dyn *args*)))
       some-failed (some (fn [res] (not (res :passed))) results)]
    (when (and some-failed (not is-repl))
      (os/exit 1))))

(defn- report "Default reporter" [results]
  (print "FAILURES:")

  # TODO: recursion
  (def failure-results
    (reduce
      (fn [acc group-result]
        (if-let [failed-children (filter (fn [res] (not (res :passed)))
                                         (group-result :children))
                 failed-group-result (merge group-result
                                            {:children failed-children})]
          (array/push acc failed-group-result)
          acc))
      (array/new)
      results))

  (defn get-spaces [n]
    (string (splice (g/to-array (g/take 10 (g/cycle [" "])))))
    (->> [" "]
         (generators/cycle)
         (generators/take 10)
         (generators/to-array)
         (splice)
         (string)))

  (defn print-failure-results [result depth]
    (def indent (get-spaces (* 2 depth)))
    (match result
      {:type 'group :group {:description desc} :children child-results}
      (do
        (print indent desc)
        (loop [child-result :in child-results]
          (print-failure-results child-result (+ 1 depth))))
      {:type 'test :test {:description desc} :error err}
      (do
        (print indent desc)
        (print err)
        (print))))

  (loop [result :in failure-results]
    (print-failure-result result 0))

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


(defn reset "Clear defined tests" []
  (set tests @[]))
