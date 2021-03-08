;;; reveal-remote-mode.el --- A remote control for Reveal -*- lexical-binding: t -*-

;; Copyright © 2021

;; Author: Love Lagerkvist
;; URL: https://github.com/motform/reveal-remote
;; Version: 210308
;; Package-Requires: ((emacs "25.1"))
;; Created: 2021-03-08
;; Keywords: tools convenience

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

;; A simple remote control for Reveal.
;; Currently requires CIDER and a pre-configured nrepl connection,
;; but my goal is to make this agnostic/usable with most repl connections.

;;; Code:

(require 'cider-eval)

;;; Customization
(defgroup reveal-remote nil
  "Reveal-remote functions and settings."
  :group 'tools
  :prefix "reveal-remote-")

(defcustom reveal-remote-mode-keymap-prefix (kbd "C-c C-r")
  "Reveal-remote keymap prefix."
  :group 'reveal-remote
  :type 'string)

;;; Internal:

(defun reveal-remote--submit-command (command)
  "Submit contents COMMAND as val to a `:vlaaad.reveal/command' map."
  (cider-interactive-eval ; how do we make sure this is in the correct env?
   (format "{:vlaaad.reveal/command %s}" command)))

;;; Interactive:

(defun reveal-remote-clear ()
  "Clear the Reveal window."
  (interactive)
  (when (not (reveal-remote--submit-command "'(clear-output)"))
    (message "Unable to send form. Are you sure you are connected to an nrepl through CIDER in this buffer?")))

(defun reveal-remote-dispose ()
  "Disposes the Reveal window."
  (interactive)
  (when (y-or-n-p "Are you sure you want to dispose of the Reveal window? ")
    (reveal-remote--submit-command "'(dispose)")))

;;; Minor Mode:

(defvar reveal-remote-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "l") #'reveal-remote-clear)
    map)
  "Keymap for reveal-remote-mode commands after `reveal-remote-mode-keymap-prefix'.")
(fset 'reval-remote-command-map reveal-remote-command-map)

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
