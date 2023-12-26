(import spork/path)
(import spork/generators)

(def divider-heavy "================================================================================")
(def divider-light "--------------------------------------------------------------------------------")

(defn- group/new []
  @{:type 'group
    :description nil
    :children @[]
    :before nil
    :before-each nil
    :after nil
    :after-each nil})

(setdyn :group (group/new))

(defn group [description thunk]
  (array/push
    ((dyn :group) :children)
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
  (array/push
    ((dyn :group) :children)
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
                 (thunk)
                 (printf "* %s ✅" desc)
                 {:type 'test :test child :passed true})
               ([err]
                (printf "* %s ❌" desc)
                {:type 'test :test child :passed false :error err}))
             {:type 'group}
             (execute-group child))
           (when-let [after-each (group :after-each)]
             (after-each)))
         (group :children)))
  (when-let [after (group :after)]
    (after))
  {:type 'group :group group :children child-results})


(defn- get-spaces [n]
  (->> [" "]
       (generators/cycle)
       (generators/take 10)
       (generators/to-array)
       (splice)
       (string)))


(defn- print-failures [results depth]
  (def indent (get-spaces (* 2 depth)))
  (match results
    {:type 'group :group {:description desc} :children children}
    (do
      (print indent (or desc "<default>"))
      (each child children
        (print-failures child (+ 1 depth))))
    {:type 'test :test {:description desc} :error err}
    (do
      (print indent desc)
      (print err)
      (print))))


(defn- filter-failures [results]
  (def filtered-children
    (reduce
      (fn [acc child]
        (match child
          {:type 'test :passed true} acc
          {:type 'test :passed false} (array/push acc child)
          {:type 'group} (array/push acc (filter-failures child))))
      (array)
      (results :children)))
  (merge results {:children filtered-children}))


(defn- count-tests [results]
  (reduce
    (fn [acc child]
      (match child
        {:type 'test :passed true} (merge acc {:passed (+ 1 (acc :passed))})
        {:type 'test :passed false} (merge acc {:failed (+ 1 (acc :failed))})))
    {:passed 0 :failed 0}
    (results :children)))


(defn- report "Default reporter" [results]
  (print "FAILURES:")
  (print-failures (filter-failures results) 0)
  (print divider-heavy)
  (print "SUMMARY:")
  (print divider-light)
  (let [{:passed num-passed :failed num-failed} (count-tests results)
        num-total (+ num-failed num-passed)]
    (printf "Total:    %i" num-total)
    (printf "Passing:  %i" num-passed)
    (printf "Failed:   %i" num-failed))
  (print divider-heavy))


(defn run-tests []
  (def result (execute-group (dyn :group)))
  (print divider-heavy)
  (report result)
  (let
      # TODO: do better and/or suppor override for exit 1
      [is-repl (and (= "janet" (path/basename (dyn *executable*)))
                    (all (fn [arg] (not= ".janet" (path/ext arg))) (dyn *args*)))
       some-failed (some (fn [res] (not (res :passed))) result)]
    (when (and some-failed (not is-repl))
      (os/exit 1))))


(defn reset "Clear defined tests" []
  (setdyn :group (group/new)))
