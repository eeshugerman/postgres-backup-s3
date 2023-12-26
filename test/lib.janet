(import spork/path)
(import spork/generators)

(def divider-heavy "================================================================================")
(def divider-light "--------------------------------------------------------------------------------")

(defn- group/new [description]
  @{:type 'group
    :description description
    :children @[]
    :before nil
    :before-each nil
    :after nil
    :after-each nil})

(var top-group (group/new "<top>"))

(defn- get-parent-group []
  (or (dyn :group) top-group))

(defn group [description thunk]
  (def parent-group (get-parent-group))
  (def this-group
    (with-dyns [:group (group/new description)]
      (thunk)
      (dyn :group)))
  (array/push (parent-group :children) this-group))

(defn before [thunk]
  (set ((get-parent-group) :before) thunk))

(defn before-each [thunk]
  (set ((get-parent-group) :before-each) thunk))

(defn after [thunk]
  (set ((get-parent-group) :after) thunk))

(defn after-each [thunk]
  (set ((get-parent-group) :after-each) thunk))

(defn test [description thunk]
  (array/push
    ((get-parent-group) :children)
    {:type 'test
     :description description
     :thunk thunk}))


(defn execute-group [group]
  # TODO: catch errors in hooks?
  # TODO: print output indentation
  (print (group :description))
  (when-let [before (group :before)]
    (before))
  (def children-results
    (map (fn [child]
           (when-let [before-each (group :before-each)]
             (before-each))
           (def child-result
             (match child
               {:type 'test :thunk thunk :description desc}
               (try
                 (do
                   (thunk)
                   (printf "* %s ✅" desc)
                   {:type 'test :description desc :passed true})
                 ([err]
                   (printf "* %s ❌" desc)
                   {:type 'test :description desc :passed false :error err}))
               {:type 'group}
               (execute-group child)))
           (when-let [after-each (group :after-each)]
             (after-each))
           child-result)
         (group :children)))
  (when-let [after (group :after)]
    (after))
  {:type 'group :description (group :description) :children children-results})


(defn- get-spaces [n]
  (->> (range n)
       (map (fn [x] " "))
       (string/join)))


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


(defn- print-failures [results depth]
  (def indent (get-spaces (* 2 depth)))
  (match results
    {:type 'group :description desc :children children}
    (do
      (print indent desc)
      (each child children
        (print-failures child (+ 1 depth))))
    {:type 'test :description desc :error err}
    (do
      (print indent desc)
      (print err)
      (print))))


(defn- count-tests [results]
  (reduce
    (fn [acc child]
      (match child
        {:type 'test :passed true} (merge acc {:passed (+ 1 (acc :passed))})
        {:type 'test :passed false} (merge acc {:failed (+ 1 (acc :failed))})
        {:type 'group} (let [counts (count-tests child)]
                         {:passed (+ (acc :passed) (counts :passed))
                          :failed (+ (acc :failed) (counts :failed))})))
    {:passed 0 :failed 0}
    (results :children)))


(defn- report "Default reporter" [results]
  # TODO: elide implicit top group
  (print "FAILURES:")
  (print divider-light)
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


(defn run-tests [&keys {:exit-on-failure exit-on-failure}]
  (print divider-heavy)
  (print "Running tests...")
  (print divider-light)
  (def results (execute-group top-group))
  (print divider-heavy)

  (report results)

  (let
    # TODO: do better and/or support override
    [is-repl (and (= "janet" (path/basename (dyn *executable*)))
                  (all (fn [arg] (not= ".janet" (path/ext arg))) (dyn *args*)))
     {:failed num-failed} (count-tests results)]
    (when (and (> num-failed 0) exit-on-failure (not is-repl))
      (os/exit 1))))

(defn reset []
  (set top-group (group/new "<top>")))
