(import spork/path)
(import spork/generators)

(def divider-heavy "================================================================================")
(def divider-light "--------------------------------------------------------------------------------")

# no reason to use a dynamic binding here since it's global anyway (?)
# actually, try an implicit toplevel group to simplifiy the code
(def toplevel :private @[])

(defn- group/new [&opt toplevel]
  @{:type 'group
    :toplevel true
    :description nil
    :children @[]
    :before nil
    :before-each nil
    :after nil
    :after-each nil})

(setdyn :group (group/new true))

(defn group [description thunk]
  (array/push ((dyn :group) :children)
              (with-dyns [:group (group/new)]
                (thunk)
                (dyn :group))))

(defn before [thunk]
  (set ((dyn :group) :before) thunk))

(defn before-each [thunk]
  (set ((dyn :group) :before-each) thunk))

(defn after [thunk]
  (set ((dyn :group) :after) thunk))

(defn after-each [thunk]
  (set ((dyn :group) :after-each) thunk))

(defn test [description thunk]
  (array/push ((dyn :group) :children)
              {:type 'test
               :description description
               :thunk thunk}))

(defn execute-group [group]
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
             {:type 'group}
             (execute-group child))
           (when-let [after-each (group :after-each)]
             (after-each)))
         (group :children)))
  (when-let [after (group :after)]
    (after))
  {:type 'group :group group :children child-results})

(defn run-tests []
  (def result (execute-group (dyn :group)))
  (print divider-heavy)
  (report result)
  (let
    # TODO: do better
    [is-repl (and (= "janet" (path/basename (dyn *executable*)))
                  (all (fn [arg] (not= ".janet" (path/ext arg))) (dyn *args*)))
     some-failed (some (fn [res] (not (res :passed))) result)]
    (when (and some-failed (not is-repl))
      (os/exit 1))))


(defn- get-spaces [n]
  (string (splice (g/to-array (g/take 10 (g/cycle [" "])))))
  (->> [" "]
       (generators/cycle)
       (generators/take 10)
       (generators/to-array)
       (splice)
       (string)))

(defn- filter-failures [group]
  # TODO: return subset of tree that only has failures
  )

(defn- report "Default reporter" [result-node]
  (print "FAILURES:")

  (def failures (filter-failures result-node))

  (defn print-failures [result-node depth]
    (def indent (get-spaces (* 2 depth)))
    (match result-node
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

  (print-failures failures)

  # TODO
  # (print divider-heavy)
  # (print "SUMMARY:")
  # (print divider-light)
  # (let [num-total (length results)
  #       num-passed (sum (map (fn [res] (if (res :passed) 1 0)) results))
  #       num-failed (- num-total num-passed)]
  #   (printf "Total:    %i" num-total)
  #   (printf "Passing:  %i" num-passed)
  #   (printf "Failed:   %i" num-failed))
  (print divider-heavy))


(defn reset "Clear defined tests" []
  (set tests @[]))
