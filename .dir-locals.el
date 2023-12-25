;;; Directory Local Variables            -*- no-byte-compile: t -*-
;;; For more information see (info "(emacs) Directory Variables")

((nil . ((eval . (advice-add 'inf-janet-project-root
                             :filter-return (lambda (path)
                                              (f-join path "test"))))))
 (sh-mode . ((sh-basic-offset . 2))))
