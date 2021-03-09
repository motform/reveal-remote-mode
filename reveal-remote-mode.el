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
;; Tested against Reveal 1.3.196

;;; Code:

(require 'cider)

;;; Customization

(defgroup reveal-remote nil
  "Reveal-remote functions and settings."
  :group  'tools
  :prefix "reveal-remote-")

(defcustom reveal-remote-mode-keymap-prefix (kbd "C-c C-a")
  "Reveal-remote keymap prefix."
  :group 'reveal-remote
  :type  'string)

(defcustom reveal-remote-views
  '("view:table"
    "view:pie-chart"
    "view:bar-chart"
    "view:line-chart"
    "view:scatter-chart"
    "view:color"
    "view:value"
    "java-bean"
    "datafy")
  "Available views in `reveal-remote-open-view'."
  :group 'reveal-remote
  :type  'list)

;;; Internal:

(defun reveal-remote--submit-command (command)
  "Submit map with key `:vlaaad.reveal/command' and COMMAND as val."
  (let ((form (format "{:vlaaad.reveal/command %s}" command)))
    (when (not (cider-interactive-eval form)) ; cider-interactive-eval returns nils on fail
      (error "Unable to send form.  Are you sure you are connected to an nrepl through CIDER in this buffer?"))))

(defun reveal-remote--open-view (value)
  "Select and open view with VALUE."
  (let ((view (completing-read "Select view: " reveal-remote-views nil :require-match)))
    (reveal-remote--submit-command
     (format "'(open-view {:fx/type action-view
                           :action :vlaaad.reveal.action/%s
                           :value %s})"
             view
             value))))

;;; Interactive:

(defun reveal-remote-clear ()
  "Clear the Reveal window."
  (interactive)
  (reveal-remote--submit-command "'(clear-output)"))

(defun reveal-remote-dispose ()
  "Disposes the Reveal window."
  (interactive)
  (when (y-or-n-p "Are you sure you want to dispose of the Reval window? ")
    (reveal-remote--submit-command "'(dispose)")))

(defun reveal-remote-submit ()
  "Submit value at point to output panel.
Ignores, and thus prints, data that might be a valid reveal command map.

NOTE: unless :env is set forms will be evaluated in the `vlaaad.reveal.ext',
NOT the namespace of the buffer (this applies to all interactions but is most notable here)."
  (interactive)
  (reveal-remote--submit-command
   (format "'(submit %s)" (cider-last-sexp))))

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
    (define-key map (kbd "q") #'reveal-remote-dispose)
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
