;;; use-package-core.el --- A configuration macro for simplifying your .emacs  -*- lexical-binding: t; -*-

;; Copyright (C) 2012-2017 John Wiegley

;; Author: Daniel Nicolai <dalanicolai@gmail.com>
;; Created: 10 Apr 2020
;; Version: 0.1
;; Keywords: zotero ivy
;; URL: https://github.com/dalanicolai/zotero-find

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Commentary:

;; The code in this package was taken and adopted from the calibre-mode package
;; found at https://github.com/whacked/calibre-mode. For now it simply searches
;; for a match of a single given query in the titles and author names of THE
;; PARENT ITEMS in the given Zotero database. ITEMS WITHOUT PARENTS ARE NOT
;; FOUND by the sql query in this package. Except for the code required for the
;; zotero-find function, the code is dysfunctional (but kept here for
;; possibility of updating/extending the package).

;;Please see README.md from the same repository for documentation.

;;; Code:
(require 'org)
(require 'cl)
(require 'sql)
(require 'seq)
(when (featurep 'ivy)
  (require 'ivy))

;; UTILITY
(defun zotero-chomp (s)
  (replace-regexp-in-string "[\s\n]+$" "" s))

;; (defun quote-% (str)
;;   (replace-regexp-in-string "%" "%%" str))

(defcustom zotero-root-dir "~/Zotero/"
  "A string with the zotero root directory containing the database .sqlite file")

(defvar zotero-db
  (concat (file-name-as-directory
           zotero-root-dir) "zotero.sqlite"))

(defvar zotero-default-opener
  (cond ((eq system-type 'gnu/linux)
         ;; HACK!
         ;; "xdg-open"
         ;; ... but xdg-open doesn't seem work as expected! (process finishes but program doesn't launch)
         ;; appears to be related to http://lists.gnu.org/archive/html/emacs-devel/2009-07/msg00279.html
         ;; you're better off replacing it with your exact program...
         ;; here we run xdg-mime to figure it out for *pdf* only. So this is not general!
         (zotero-chomp
          (shell-command-to-string
           (concat
            "grep Exec "
            (first
             ;; attempt for more linux compat, ref
             ;; http://askubuntu.com/questions/159369/script-to-find-executable-based-on-extension-of-a-file
             ;; here we try to find the location of the mimetype opener that xdg-mime refers to.
             ;; it works for okular (Exec=okular %U %i -caption "%c"). NO IDEA if it works for others!
             (delq nil (let ((mime-appname (zotero-chomp (replace-regexp-in-string
                                                           "kde4-" "kde4/"
                                                           (shell-command-to-string "xdg-mime query default application/pdf")))))

                         (mapcar
                          #'(lambda (dir) (let ((outdir (concat dir "/" mime-appname))) (if (file-exists-p outdir) outdir)))
                          '("~/.local/share/applications" "/usr/local/share/applications" "/usr/share/applications")))))
            "|head -1|awk '{print $1}'|cut -d '=' -f 2"))))
        ((eq system-type 'windows-nt)
         ;; based on
         ;; http://stackoverflow.com/questions/501290/windows-equivalent-of-the-mac-os-x-open-command
         ;; but no idea if it actually works
         "start")
        ((eq system-type 'darwin)
         "open")
        (t (message "unknown system!?"))))

;; TODO: consolidate default-opener with dispatcher
(defun zotero-open-with-default-opener (filepath)
  (if (eq system-type 'windows-nt)
      (start-process "shell-process" "*Messages*"
                     "cmd.exe" "/c" filepath)
    (start-process "shell-process" "*Messages*"
                   zotero-default-opener filepath)))

;; CREATE TABLE pdftext ( filepath CHAR(255) PRIMARY KEY, content TEXT );
;; (defvar zotero-text-cache-db (expand-file-name "~/Documents/pdftextcache.db"))
;; (defun zotero-get-cached-pdf-text (pdf-filepath)
;;   (let ((found-text (shell-command-to-string
;;                      (format "%s -separator '\t' '%s' 'SELECT content FROM pdftext WHERE filepath = '%s'" sql-sqlite-program zotero-text-cache-db pdf-filepath))))
;;     (if (< 0 (length found-text))
;;         found-text
;;       (let ((text-extract (shell-command-to-string
;;                            (format "pdftotext '%s' -" pdf-filepath))))
;;         (message "supposed to insert this!")
;;         ))))


;; (shell-command-to-string
;;  (format "%s -separator '\t' '%s' '%s'" sql-sqlite-program zotero-db ".schema books"))

(defun zotero-query (sql-query)
  (interactive)
  (shell-command-to-string
   (format "%s -separator \"\t\" \"%s%s\" \"%s\""
           "sqlite3"
           (file-name-as-directory zotero-root-dir)
           "zotero.sqlite"
           sql-query)))

(defun zotero-query-to-alist (query-result)
  "builds alist out of a full zotero-query query record result"
  (if query-result
      (let ((spl-query-result (split-string (zotero-chomp query-result) "\t")))
        `((:id                     ,(nth 0 spl-query-result))
          (:book-dir               ,(nth 1 spl-query-result))
          (:file-name              ,(nth 2 spl-query-result))
          (:extra           ,(nth 3 spl-query-result))
          (:file-path    ,(concat (file-name-as-directory zotero-root-dir)
                                  "storage/"
                                  (if (nth 1 spl-query-result)
                                      (file-name-as-directory (nth 1 spl-query-result))
                                    "")
                                  (if (> (length (nth 3 spl-query-result)) 0)
                                      (substring (nth 3 spl-query-result) 8 nil)
                                    ""
                                    )))))))

(defun zotero-build-default-query (whereclause &optional limit)
  (concat "SELECT itemAttachments . itemid, key, value, path "
          "from itemAttachments "
          "left join items using(itemID) "
          "left join itemdata ON itemData.itemID=itemAttachments.parentitemID "
          "left join itemDataValues using(valueID) "
          whereclause))

(defun zotero-build-notes-query (whereclause &optional limit)
  (concat "SELECT itemAttachments . itemid, key, note, path "
          "from itemAttachments "
          "left join items using(itemID) "
          "left join itemNotes using(parentItemID)"
          whereclause))

(defun zotero-query-by-field (wherefield argstring)
  (concat "WHERE lower(" wherefield ") LIKE '%%"
          (format "%s" (downcase argstring))
          "%%'"))

(concat "hello" "world")
(defun zotero-read-query-filter-command ()
  (interactive)
  (let* (;; prompt &optional initial keymap read history default
         (search-string (read-string "Search Zotero for: "
                                             )))
    ;;      (spl-arg (split-string search-string ":")))
    ;; (if (and (< 1 (length spl-arg))
    ;;          (= 1 (length (first spl-arg))))
    ;;     (let* ((command (downcase (first spl-arg)))
    ;;            (argstring (second spl-arg))
    ;;            (wherefield
    ;;             (cond ((string= "a" (substring command 0 1))
    ;;                    "b.author_sort")
    ;;                   ((string= "t" (substring command 0 1))
    ;;                    "b.title")
    ;;                   )))
    ;;       (zotero-query-by-field wherefield argstring))
         (print (format "WHERE fieldID = 110 and itemAttachments . itemID in (SELECT DISTINCT itemAttachments . itemid from itemAttachments left join itemdata ON itemData.itemID=itemAttachments.parentitemID left join itemcreators ON itemCreators.itemID=itemAttachments.parentitemID left join creators using(creatorID) left join itemDataValues using(valueid) WHERE (lastName like '%%%s%%' or value like '%%%s%%') and parentItemID is not NULL)"
                 (downcase search-string) (downcase search-string)))))

;; (defun zotero-read-query-filter-command ()
;;   (interactive)
;;   (let* ((default-string (if mark-active (zotero-chomp (buffer-substring (mark) (point)))))
;;          ;; prompt &optional initial keymap read history default
;;          (search-string (read-string (format "Search Zotero for%s: "
;;                                              (if default-string
;;                                                  (concat " [" default-string "]")
;;                                                "")) nil nil default-string))
;;          (spl-arg (split-string search-string ":")))
;;     (if (and (< 1 (length spl-arg))
;;              (= 1 (length (first spl-arg))))
;;         (let* ((command (downcase (first spl-arg)))
;;                (argstring (second spl-arg))
;;                (wherefield
;;                 (cond ((string= "a" (substring command 0 1))
;;                        "b.author_sort")
;;                       ((string= "t" (substring command 0 1))
;;                        "b.title")
;;                       )))
;;           (zotero-query-by-field wherefield argstring))
;;       (format "WHERE lower(b.author_sort) LIKE '%%%s%%' OR lower(b.title) LIKE '%%%s%%'"
;;               (downcase search-string) (downcase search-string)))))

;; (defun zotero-list ()
;;   (interactive)
;;   (message (quote-% (zotero-query
;;             (concat "SELECT b.path FROM books AS b "
;;                     (zotero-read-query-filter-command))))))

(defun zotero-list ()
    (interactive)
  (ivy-read "Zoek maar uit: "
            (split-string
             (shell-command-to-string
              (concat "sqlite3 -list /mnt/4EEDC07F44412A81/Zotero/zotero.sqlite "
                      (shell-quote-argument "SELECT value FROM itemdata left join itemdatavalues using(valueid) where fieldid = 110"))) "\n")))

(defun zotero-get-cached-pdf-text (pdf-filepath)
  (let ((found-text (shell-command-to-string
                     (format "%s -separator '\t' '%s' 'SELECT content FROM pdftext WHERE filepath = '%s'" sql-sqlite-program zotero-text-cache-db pdf-filepath))))
    (if (< 0 (length found-text))
        found-text
      (let ((text-extract (shell-command-to-string
                           (format "pdftotext '%s' -" pdf-filepath))))
        (message "supposed to insert this!")
        ))))

(defun zotero-open-citekey ()
  (interactive)
  (if (word-at-point)
      (let ((where-string
             (replace-regexp-in-string
              ;; capture all up to optional "etal" into group \1
              ;; capture 4 digits of date          into group \2
              ;; capture first word in title       into group \3
              "\\b\\([^ :;,.]+?\\)\\(?:etal\\)?\\([[:digit:]]\\\{4\\\}\\)\\(.*?\\)\\b"
              "WHERE lower(b.author_sort) LIKE '%\\1%' AND lower(b.title) LIKE '\\3%' AND b.pubdate >= '\\2-01-01' AND b.pubdate <= '\\2-12-31' LIMIT 1" (word-at-point))))
        (mark-word)
        (zotero-find (zotero-build-default-query where-string)))
    (message "nothing at point!")))

(defun getattr (my-alist key)
  (cadr (assoc key my-alist)))

(defun zotero-make-citekey (zotero-res-alist)
  "return some kind of a unique citation key for BibTeX use"
  (let* ((stopword-list '("the" "on" "a"))
         (spl (split-string (zotero-chomp (getattr zotero-res-alist :book-dir)) "&"))
         (first-author-lastname (first (split-string (first spl) ",")))
         (first-useful-word-in-title
          ;; ref fitlering in http://www.emacswiki.org/emacs/ElispCookbook#toc39
          (first (delq nil
                  (mapcar
                   (lambda (token) (if (member token stopword-list) nil token))
                   (split-string (downcase (getattr zotero-res-alist :file-name)) " "))))))
    (concat
     (downcase (replace-regexp-in-string  "\\W" "" first-author-lastname))
     (if (< 1 (length spl)) "etal" "")
     (substring (getattr zotero-res-alist :book-pubdate) 0 4)
     (downcase (replace-regexp-in-string  "\\W.*" "" first-useful-word-in-title)))))

(defun mark-aware-copy-insert (content)
  "copy to clipboard if mark active, else insert"
  (if mark-active
      (progn (kill-new content)
             (deactivate-mark))
    (insert content)))

;; Define the result handlers here in the form of (hotkey description
;; handler-function) where handler-function takes 1 alist argument
;; containing the result record.
(setq zotero-handler-alist
      '(("o" "open"
         (lambda (res) (find-file-other-window (getattr res :file-path))))
        ("O" "open other frame"
         (lambda (res) (find-file-other-frame (getattr res :file-path))))
        ("v" "open with default viewer"
         (lambda (res)
           (zotero-open-with-default-opener (getattr res :file-path))))
        ("x" "open with xournal"
         (lambda (res)
           (start-process "xournal-process" "*Messages*" "xournal"
                          (let ((xoj-file-path (concat zotero-root-dir "/"
                                                       (getattr res :book-dir)
                                                       "/"
                                                       (getattr res :book-name)
                                                       ".xoj")))
                            (if (file-exists-p xoj-file-path)
                                xoj-file-path
                              (getattr res :file-path))))))
        ("s" "insert zotero search string"
         (lambda (res) (mark-aware-copy-insert
                        (concat "title:\"" (getattr res :file-name) "\""))))
        ("c" "insert citekey"
         (lambda (res) (mark-aware-copy-insert (zotero-make-citekey res))))
        ("i" "get book information (SELECT IN NEXT MENU) and insert"
         (lambda (res)
           (let ((opr
                  (char-to-string
                   (read-char
                    ;; render menu text here
                    (concat "What information do you want?\n"
                            "i : values in the book's `Ids` field (ISBN, DOI...)\n"
                            "d : pubdate\n"
                            "a : author list\n")))))
             (cond ((string= "i" opr)
                    ;; stupidly just insert the plain text result
                    (mark-aware-copy-insert
                     (zotero-chomp
                      (zotero-query
                       (concat "SELECT "
                               "idf.type, idf.val "
                               "FROM identifiers AS idf "
                               (format "WHERE book = %s" (getattr res :id)))))))
                   ((string= "d" opr)
                    (mark-aware-copy-insert
                     (substring (getattr res :book-pubdate) 0 10)))
                   ((string= "a" opr)
                    (mark-aware-copy-insert
                     (zotero-chomp (getattr res :book-dir))))
                   (t
                    (deactivate-mark)
                    (message "cancelled"))))))
        ("p" "insert file path"
         (lambda (res) (mark-aware-copy-insert (getattr res :file-path))))
        ("t" "insert title"
         (lambda (res) (mark-aware-copy-insert (getattr res :file-name))))
        ("g" "insert org link"
         (lambda (res)
           (insert (format "[[%s][%s]]"
                           (getattr res :file-path)
                           (concat (zotero-chomp (getattr res :book-dir))
                                   ", "
                                   (getattr res :file-name))))))
        ("j" "insert entry json"
         (lambda (res) (mark-aware-copy-insert (json-encode res))))
        ("X" "open as plaintext in new buffer (via pdftotext)"
         (lambda (res)
           (let* ((citekey (zotero-make-citekey res)))
             (let* ((pdftotext-out-buffer
                     (get-buffer-create
                      (format "pdftotext-extract-%s" (getattr res :id)))))
               (set-buffer pdftotext-out-buffer)
               (insert (shell-command-to-string (concat "pdftotext '"
                                                        (getattr res :file-path)
                                                        "' -")))
               (switch-to-buffer-other-window pdftotext-out-buffer)
               (beginning-of-buffer)))))
        ("q" "(or anything else) to cancel"
         (lambda (res)
           (deactivate-mark)
           (message "cancelled")))))

(defun zotero-file-interaction-menu (zotero-item)
  (if (file-exists-p (getattr zotero-item :file-path))
      (let ((opr (char-to-string (read-char
                                  ;; render menu text here
                                  (concat (format "(%s) [%s] found, what do?\n"
                                                  (getattr zotero-item :extra)
                                                  (getattr zotero-item :book-name))
                                          (mapconcat #'(lambda (handler-list)
                                                         (let ((hotkey      (elt handler-list 0))
                                                               (description (elt handler-list 1))
                                                               (handler-fn  (elt handler-list 2)))
                                                           ;; ULGY BANDAID HACK
                                                           ;; replace "insert" with "copy to clipboard" if mark-active
                                                           (print (format "MESSSSSSSSSSSSSSSSSSSSSSSSSSAGE %s" description))
                                                           (format " %s :   %s"
                                                                   hotkey
                                                                   (if mark-active
                                                                       (replace-regexp-in-string "insert \\(.*\\)" "copy \\1 to clipboard" description)
                                                                     description)))
                                                         ) zotero-handler-alist "\n"))))))
        (funcall
         (elt (if (null (assoc opr zotero-handler-alist)) (assoc "q" zotero-handler-alist)
                (assoc opr zotero-handler-alist)) 2) zotero-item))
    (message "didn't find that file")))

(defun zotero--make-book-alist
    (id file-name book-dir extra)
  `((:id ,id)
    (:file-name ,file-name)
    (:book-dir ,book-dir)
    (:extra ,extra)))

(defun zotero--make-item-selectable-string
    (book-alist)
  (format
   "(%s) [%s] %s -- %s"
   (getattr book-alist :id)
   (getattr book-alist :book-dir)
   (getattr book-alist :file-name)
   (getattr book-alist :extra)))

(if (featurep 'ivy)

    (defun zotero-format-selector-menu (zotero-item-list)
      (ivy-read "Pick a book: "
                (let (display-alist)
                  (dolist (item zotero-item-list display-alist)
                    (setq
                     display-alist
                     (cons
                      (list (zotero--make-item-selectable-string item)
                            item)
                      display-alist))))
                :action (lambda (item)
                          (zotero-file-interaction-menu (cadr item)))))

  (defun zotero-format-selector-menu (zotero-item-list)
    (let ((chosen-item
           (completing-read "Pick book: "
                            (mapcar 'zotero--make-item-selectable-string
                                    zotero-item-list)
                            nil t)))
      (zotero-file-interaction-menu
       (find-if (lambda (item)
                  (equal chosen-item
                         (zotero--make-item-selectable-string item)))
                zotero-item-list)))))

(defun zotero-find (&optional custom-query)
  (interactive)
  (let* ((query (read-string "Search for? "))
         (sql-query (zotero-build-default-query
                     (format
                      (concat "WHERE fieldID = 110 and itemAttachments . itemID "
                              "in (SELECT DISTINCT itemAttachments . itemid "
                              "from itemAttachments "
                              "left join itemdata ON itemData.itemID=itemAttachments.parentitemID "
                              "left join itemcreators ON itemCreators.itemID=itemAttachments.parentitemID "
                              "left join creators using(creatorID) left join itemDataValues using(valueid) "
                              ;; "WHERE (lastName like '%taus%' or value like '%taus%') and parentItemID is not NULL)")
                              "WHERE (lastName like '%%%s%%' or value like '%%%s%%') and parentItemID is not NULL)")
                      query query)))
         (query-result (zotero-query sql-query))
         (line-list (split-string (zotero-chomp query-result) "\n"))
         (num-result (length line-list)))
    (if (= 0 num-result)
        (progn
          (message "nothing found.")
          (deactivate-mark))
      (let ((res-list (mapcar #'(lambda (line) (zotero-query-to-alist line)) line-list)))
        (zotero-format-selector-menu res-list)))))
        ;; (if (= 1 (length res-list))
        ;;     (zotero-file-interaction-menu (car res-list))
        ;;   (zotero-format-selector-menu res-list))))))

(defun zotero-find-notes (&optional custom-query)
  (interactive)
  (let* ((query (read-string "Search for? "))
         (sql-query (zotero-build-notes-query
                     (format
                      (concat "WHERE itemAttachments . itemID "
                              "in (SELECT DISTINCT itemAttachments . itemid "
                              "from itemAttachments "
                              "left join itemNotes using(parentitemID) "
                              "left join itemcreators ON itemCreators.itemID=itemAttachments.parentitemID "
                              "left join creators using(creatorID) "
                              "WHERE (lastName like '%%%s%%' or note like '%%%s%%') and parentItemID is not NULL)")
                      query query)))
         (query-result (zotero-query sql-query))
         (line-list (split-string (zotero-chomp query-result) "\n"))
         (num-result (length line-list)))
    (if (= 0 num-result)
        (progn
          (message "nothing found.")
          (deactivate-mark))
      (let ((res-list (mapcar #'(lambda (line) (zotero-query-to-alist line)) line-list)))
        (if (= 1 (length res-list))
            (zotero-file-interaction-menu (car res-list))
          (zotero-format-selector-menu res-list))))))

(global-set-key "\C-cK" 'zotero-open-citekey)

;; ORG MODE INTERACTION
(org-add-link-type "zotero" 'org-zotero-open 'org-zotero-link-export)

(defun org-zotero-open (org-link-text)
  ;; TODO: implement link parsers; assume default is title, e.g.
  ;; [[zotero:Quick Start Guide]]
  ;; will need to handle author shibori
  (zotero-find
   (zotero-build-default-query
    (zotero-query-by-field "b.title" org-link-text))))

(defun org-zotero-link-export (link description format)
  "FIXME: stub function"
  (concat "link in zotero: " link " (" description ")"))

(provide 'zotero-find)
