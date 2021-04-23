;;; reveal-remote-mode.el --- A remote control for Reveal -*- lexical-binding: t -*-

;; Copyright © 2021

;; Author: Love Lagerkvist
;; URL: https://github.com/motform/reveal-remote-mode
;; Version: 210309
;; Package-Requires: ((emacs "25.1") (clojure-mode "5.9") (cider "0.24.0"))
;; Created: 2021-03-08
;; Keywords: tools convenience clojure cider

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; A simple remote control for Reveal (https://vlaaad.github.io/reveal/).
;; Provides functions for submitting values, opening views and controlling the window.
;;
;; Currently requires CIDER and a pre-configured nrepl connection,
;; but my goal is to make this work with inf-clojure as well.
;;
;; Tested against Reveal 1.3.209

;;; Code:

(require 'cider)
(eval-when-compile (require 'subr-x))

;;; Customization:

(defgroup reveal-remote nil
  "Reveal-remote functions and settings."
  :group  'tools
  :prefix "reveal-remote-")

(defcustom reveal-remote-mode-keymap-prefix (kbd "C-c C-a")
  "Reveal-remote keymap prefix."
  :group 'reveal-remote
  :type  'string)

(defcustom reveal-remote-eval-in-other-ns t
  "If non-nil (default), evaluates forms in the current buffer's namespace.

By default, Reveal evaluates any forms it encounters in vlaaad.reveal.ext,
which means that any unknown symbols will result in compile errors."
  :group 'reveal-remote
  :type  'boolean)

(defcustom reveal-remote-other-ns "*ns*"  ; not sure how robust it is to rely on *ns*
  "The namespace used when `reveal-remote-eval-in-other-ns' is non-nil."
  :group 'reveal-remote
  :type  'string)

(defcustom reveal-remote-env nil
  "If non nil, supplies its contents as a map under the :env key in the command."
  :group 'reveal-remote
  :type  'string)

(defcustom reveal-remote-views
  '(("view:table"         . ":vlaaad.reveal.action/view:table")
    ("view:pie-chart"     . ":vlaaad.reveal.action/view:pie-chart")
    ("view:bar-chart"     . ":vlaaad.reveal.action/view:bar-chart")
    ("view:line-chart"    . ":vlaaad.reveal.action/view:line-chart")
    ("view:scatter-chart" . ":vlaaad.reveal.action/view:scatter-chart")
    ("view:color"         . ":vlaaad.reveal.action/view:color")
    ("view:value"         . ":vlaaad.reveal.action/view:value")
    ("java-bean"          . ":vlaaad.reveal.action/java-bean")
    ("datafy"             . ":vlaaad.reveal.action/datafy"))
  "Available views in `reveal-remote-open-view'."
  :group 'reveal-remote
  :type  'alist)

;;; Internal:

(defun reveal-remote--eval-command (command &optional arg)
  "Evaluate the Reveal command form with `ARG' applied to `COMMAND'."
  (let* ((command-map (reveal-remote--build-command-map command arg))
         (success-p   (cider-interactive-eval command-map)))  ; cider-interactive-eval nils on fail
    (when (not success-p)
      (error "Unable to send form.  Are you sure you are connected to an nrepl through CIDER in this buffer?"))))

(defun reveal-remote--build-command-map (command &optional arg)
  "Return the finished Reveal command map by setting flags, adding ARG and boilerplate to COMMAND."
  (format "{:vlaaad.reveal/command '((requiring-resolve 'vlaaad.reveal.ext/%s) %s) %s %s}"
          command
          (or arg "")
          (or (when reveal-remote-eval-in-other-ns
                (format ":ns %s" reveal-remote-other-ns)) "")
          (or (when reveal-remote-env
                (format ":env %s" reveal-remote-env)) "")))

(defun reveal-remote--alist-completing-read (alist msg)
  "Prompt a `completing-read' of keys of ALIST with MSG and return associated val."
  (thread-first (completing-read msg (mapcar 'car alist) nil :require-match)
    (assoc alist)
    cdr))

(defun reveal-remote--open-view (value)
  "Select and open view with VALUE."
  (let ((action (reveal-remote--alist-completing-read reveal-remote-views "Select view: ")))
    (reveal-remote--eval-command
     "open-view"
     (format "{:fx/type  vlaaad.reveal.ext/action-view
                :action  %s
                :value   %s}"
             action
             value))))

;;; Interactive:

(defun reveal-remote-clear ()
  "Clear the Reveal window."
  (interactive)
  (reveal-remote--eval-command "clear-output"))

(defun reveal-remote-close-all-views ()
  "Close all open Reveal views."
  (interactive)
  (reveal-remote--eval-command "close-all-views"))

(defun reveal-remote-dispose ()
  "Disposes the Reveal window."
  (interactive)
  (when (y-or-n-p "Are you sure you want to dispose of the Reval window? ")
    (reveal-remote--eval-command "dispose")))

(defun reveal-remote-submit ()
  "Submit value at point to output panel.
Ignores, and thus prints, data that might be a valid reveal command map."
  (interactive)
  (reveal-remote--eval-command "submit" (cider-last-sexp)))

(defun reveal-remote-open-view-last-sexp ()
  "Open selected view with expression preceding point.
Add new views via `reveal-remote-views'.

NOTE: does not attempt to validate the view against the value,
meaning that you are able to trigger exceptions."
  (interactive)
  (reveal-remote--open-view (cider-last-sexp)))

(defun reveal-remote-open-view-defun-at-point ()
  "Open selected view with the top level from.
Add new views via `reveal-remote-views'.

NOTE: does not attempt to validate the view against the value,
meaning that you are able to trigger exceptions."
  (interactive)
  (reveal-remote--open-view (cider-defun-at-point)))

;;; Minor Mode:

(defvar reveal-remote-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "l") #'reveal-remote-clear)
    (define-key map (kbd "q") #'reveal-remote-close-all-views)
    (define-key map (kbd "x") #'reveal-remote-dispose)
    (define-key map (kbd "e") #'reveal-remote-submit)
    (define-key map (kbd "v") #'reveal-remote-open-view-last-sexp)
    (define-key map (kbd "c") #'reveal-remote-open-view-defun-at-point)
    map)
  "Keymap for reveal-remote-mode commands after `reveal-remote-mode-keymap-prefix'.")
(fset 'reveal-remote-command-map reveal-remote-command-map)

(defvar reveal-remote-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map reveal-remote-mode-keymap-prefix 'reveal-remote-command-map)
    map)
  "Keymap for reveal-remote-mode.")

;;;###autoload
(define-minor-mode reveal-remote-mode
  "Remote control Reveal from the comfort of Emacs."
  :lighter "reveal-remote"
  :keymap   reveal-remote-mode-map
  :group   'reveal-remote
  :require 'reveal-remote)

(provide 'reveal-remote-mode)
;;; reveal-remote-mode.el ends here
