;; Hack to get a little better java 1.5 support
;; Copied from http://osdir.com/ml/emacs.jdee/2007-07/msg00022.html
;; ... and adapted to allow enums

(require 'font-lock)
(require 'cc-mode)

(let* ((java-keywords
        (eval-when-compile
          (regexp-opt
           '("catch" "class" "do" "else" "enum" "super" "this" "finally" "for" "if"
             "implements" "extends" "throws" "instanceof" "new"
             "interface" "return" "switch" "throw" "try" "while"))))
       ;;
       ;; Classes immediately followed by an object name.
       (java-type-names
        `(mapconcat 'identity
                    (cons
                     ,(eval-when-compile
                        (regexp-opt '("boolean" "char" "byte" "short" "int" "long"
                                      "float" "double" "void")))
                     java-font-lock-extra-types)
                    "\\|"))
       (java-type-names-depth `(regexp-opt-depth ,java-type-names))
       ;;
       ;; These are eventually followed by an object name.
       (java-type-specs
        (eval-when-compile
          (regexp-opt
           '("abstract" "const" "final" "synchronized" "transient" "static"
             "volatile" "public" "private" "protected" "native"
             "strictfp"))))
       )

  (setq java-font-lock-keywords-3
        (append

         (list
          ;; support static import statements
          '("\\<\\(import\\)\\>\\s-+\\(static\\)\\s-+\\(\\sw+\\)"
            (1 font-lock-keyword-face)
            (2 font-lock-keyword-face)
            (3 (if (equal (char-after (match-end 0)) ?\.)
                   'jde-java-font-lock-package-face
                 'font-lock-type-face))
            ("\\=\\.\\(\\sw+\\)" nil nil
             (1 (if (and (equal (char-after (match-end 0)) ?\.)
                         (not (equal (char-after (+ (match-end 0) 1)) ?\*)))
                    'jde-java-font-lock-package-face
                  'font-lock-type-face))))
          )

         java-font-lock-keywords-2

         ;;
         ;; More complicated regexps for more complete highlighting for types.
         ;; We still have to fontify type specifiers individually, as Java is hairy.
         (list
          ;;
          ;; Fontify class names with ellipses
          `(eval .
                 (cons (concat "\\<\\(" ,java-type-names "\\)\\>\\.\\.\\.[^.]")
                       '(1 font-lock-type-face)))
          ;;
          ;; Fontify random types immediately followed by an item or items.
          `(eval .
                 (list (concat "\\<\\(\\(?:" ,java-type-names "\\)"
                               "\\(?:\\(?:<.*>\\)\\|\\>\\)\\(?:\\.\\.\\.\\)?\\)"
                               "\\([ \t]*\\[[ \t]*\\]\\)*"
                               "\\([ \t]*\\sw\\)")
                       ;; Fontify each declaration item.
                       (list 'font-lock-match-c-style-declaration-item-and-skip-to-next
                             ;; Start and finish with point after the type specifier.
                             (list 'goto-char (list 'match-beginning
                                                    (+ ,java-type-names-depth 3)))
                             (list 'goto-char (list 'match-beginning
                                                    (+ ,java-type-names-depth 3)))
                             ;; Fontify as a variable or function name.
                             '(1 (if (match-beginning 2)
                                     font-lock-function-name-face
                                   font-lock-variable-name-face)))))
          ;;
          ;; Fontify those that are eventually followed by an item or items.
          (list (concat "\\<\\(" java-type-specs "\\)\\>"
                        "\\([ \t]+\\sw+\\>"
                        "\\([ \t]*\\[[ \t]*\\]\\)*"
                        "\\)*")
                ;; Fontify each declaration item.
                '(font-lock-match-c-style-declaration-item-and-skip-to-next
                  ;; Start with point after all type specifiers.
                  (goto-char (or (match-beginning 5) (match-end 1)))
                  ;; Finish with point after first type specifier.
                  (goto-char (match-end 1))
                  ;; Fontify as a variable or function name.
                  (1 (if (match-beginning 2)
                         font-lock-function-name-face
                       font-lock-variable-name-face))))

          )))
  )
