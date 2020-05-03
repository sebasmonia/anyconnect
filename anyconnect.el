;;; anyconnect.el --- Wrapper over the `vpncli` from Cisco AnyConnect  -*- lexical-binding: t; -*-

;; Copyright (C) 2020 Sebastian Monia
;;
;; Author: Sebastian Monia <smonia@outlook.com>
;; URL: https://github.com/sebasmonia/anyconnect.git
;; Package-Requires: ((emacs "25.1"))
;; Version: 1.0
;; Keywords: tools convenience networking

;; This file is not part of GNU Emacs.

;;; License: MIT

;;; Commentary:

;; For more details on configuration see https://github.com/sebasmonia/anyconnect/blob/master/README.md

;;; Code:

(require 'cl-lib)

(defgroup anyconnect nil
  "Connect to a Cisco VPN using the \"vpncli\" tool"
  :group 'extensions)

(defcustom anyconnect-path "C:\\Program Files (x86)\\Cisco\\Cisco AnyConnect Secure Mobility Client\\vpncli.exe"
  "Path to the vpncli tool."
  :type 'string
  :group 'anyconnect)

(defcustom anyconnect-steps '((identity . "\n")
                              (read-string . "Username: ")
                              (read-passwd . "Password: ")
                              (read-passwd . "Second password: ")
                              (identity . "y"))
  "Steps to follow to connect to the VPN.
Each element is a cons cell (Func . \"Param\")."
  :type '(alist :key-type (symbol :tag "Action")
                :value-type (string :tag "Value"))
  :group 'anyconnect)

(defcustom anyconnect-modeline-indicator 'connected
  "Whether to show a modeline indicator. 'connected (default)
shows the string \"VPN\" when you are connected. 'always shows \"VPN:On\"
or \"VPN:Off\" depending on status. 'never doesn't show anything."
  :type 'symbol
  :group 'anyconnect)

(defcustom anyconnect-log-buffer-name "*VPN Log*"
  "Name of the anyconnect package log buffer."
  :type 'string
  :group 'anyconnect)

(defcustom anyconnect-log-cli-output t
  "If t, log all the tool's output. Intended for debugging."
  :type 'boolean
  :group 'anyconnect)

(defvar anyconnect--process-name "*VPNCLI*" "Name of the vpncli async process used to connect to the VPN")
(defvar anyconnect--status 'disconnected "VPN connection status, used internally.  Symbol values: connected, disconnected, connecting.")
(defvar anyconnect--vpncli-output "" "Accumulates the output of the async process used to connect.")
(defvar anyconnect--connected-marker "state: Connected" "String marker for connection state and output of connection attempt.")
(defvar anyconnect--connecting-error-marker "Authentication failed." "String marker for failed connection.")

;;------------------Package infrastructure----------------------------------------

(defun anyconnect--message (text)
  "Show TEXT as a message and log it."
  (message text)
  (anyconnect--log "Message:" text "\n"))

(defun anyconnect--log (&rest to-log)
  "Append TO-LOG to the log buffer.  Intended for internal use only.
Adds a timestamp to each message"
  (let ((log-buffer (get-buffer-create anyconnect-log-buffer-name))
        (text (cl-reduce (lambda (accum elem) (concat accum " " (prin1-to-string elem t))) to-log)))
    (with-current-buffer log-buffer
      (goto-char (point-max))
      (insert "[" (format-time-string "%F %T") "]\n"
              text "\n"))))

;;------------------VPN connection via async process------------------------------

(defun anyconnect--start-connection (commands)
  "Run vpncli as a process, and send connection COMMANDS.
The output is analyzed in `anyconnect--process-connection-output', eventually killing
the process."
  (anyconnect--message "VPN: Connecting...")
  (let ((process (start-process anyconnect--process-name "*VPNCLI BUF*"
                                anyconnect-path "-s")))
    (set-process-filter process #'anyconnect--process-connection-output)
    (setq anyconnect--status 'connecting)
    (process-send-string process commands)))

(defun anyconnect--process-connection-output (_process output)
  "Accumulate the OUTPUT of a vpncli PROCESS, and kill it when done.
We know we are done based on certain text markers."
  ;; the test below diffentiates a command being processed from
  ;; one where we timed out but might still be running
  (setq anyconnect--vpncli-output (concat anyconnect--vpncli-output output))
  (anyconnect--update-modeline)
  (when (string-match-p anyconnect--connected-marker output)
    ;; command completed and we are connected
    (anyconnect--kill-process-and-log)
    (setq anyconnect--status 'connected)
    (anyconnect--message "VPN: Connection successful!"))
  (when (string-match-p anyconnect--connecting-error-marker output)
    ;; command completed but it didn't work
    (anyconnect--message "VPN: ERROR. See log buffer for vpncli output.")
    (anyconnect--kill-process-and-log)
    (setq anyconnect--status 'disconnected)))

(defun anyconnect--kill-process-and-log ()
  "Kill the vpncli async process if it is still running.
Log the process output for debugging."
  (when (get-process anyconnect--process-name)
    (anyconnect--log "-----\nClosing  vpncli process, output:\n"
                     anyconnect--vpncli-output
                     "\n-----")
    (kill-process anyconnect--process-name)
    (setq anyconnect--vpncli-output "")))

(defun anyconnect--get-step-value (a-step)
  (let ((func (car a-step))
        (param (cdr a-step)))
    (funcall func param)))

;;------------------Sync calls to vpncli------------------------------------------

(defun anyconnect--run-command (args-list)
  "Feed ARGS-LIST to the vpncli and return the output."
  (shell-command-to-string
    (string-join (cl-concatenate 'list
                                 (list (shell-quote-argument anyconnect-path) "-s")
                                 args-list)
                 " ")))

(defun anyconnect--get-hosts ()
  "Get the list of available hosts."
  (anyconnect--log "Getting list of available hosts")
  (let ((output (anyconnect--run-command '("hosts"))))
    (mapcar (lambda (host) (substring host 2))
              (cl-remove-if-not (lambda (line)
                                  (string-prefix-p "> "
                                                   line))
                                (mapcar 'string-trim (split-string output "\n"))))))

(defun anyconnect--refresh-state ()
  "Update the connection status by calling vpnli.
Just in case we still think we are connected, but aren't. Also updates the modeline"
  (anyconnect--log "Refreshing internal state using vpncli")
  ;; In case there's a connecting attempt stuck, after this our status can
  ;; only be connected or disconnected
  (anyconnect--kill-process-and-log)
  (let ((output (anyconnect--run-command '("state"))))
    (if (string-match-p anyconnect--connected-marker
                        output)
        (setq anyconnect--status 'connected)
      (setq anyconnect--status 'disconnected)))
  (anyconnect--update-modeline))

;;------------------Modeline indicator--------------------------------------------

(defun anyconnect--update-modeline ()
  "Updates the mode line lighter, respecting `anyconnect-modeline-indicator'."
  ;; concat to "" to account for the default `nil' value in a simple way
  (let ((clean (replace-regexp-in-string " VPN\\(:On\\|:Off\\)*" ""
                                         (concat global-mode-string "")))
        (vpn-lighter ""))
    (cond ((eq anyconnect-modeline-indicator 'always)
           (setq vpn-lighter (concat
                              " VPN:"
                              (if (eq anyconnect--status 'connected)
                                  "On"
                                "Off"))))
          ((and (eq anyconnect-modeline-indicator 'connected)
                (eq anyconnect--status 'connected)
                (setq vpn-lighter " VPN"))))
    (setq global-mode-string (concat clean vpn-lighter))))

;;------------------Public API----------------------------------------------------

(defun anyconnect-connected-p (&optional refresh-status)
  "Whether the VPN is connected. Optional parameter REFRESH-STATUS forces a refresh by calling vpncli."
  (when refresh-status
    (anyconnect--refresh-state))
  (eq anyconnect--status 'connected))

(defun anyconnect-status (&optional refresh-status)
  "Current VPN status. Optional parameter REFRESH-STATUS forces a refresh by calling vpncli."
  (interactive "P")
  (when refresh-status
    (anyconnect--refresh-state))
  anyconnect--status)

(defun anyconnect-connect (host-name)
  "Start a connection to the VPN. If HOST-NAME is not specified, it will be prompted.
The list of steps to connect is configured via `anyconnect-steps'."
  (interactive
   (list (completing-read "Select host:"
                          (anyconnect--get-hosts)
                          nil
                          t)))
  (anyconnect--update-modeline)
  (let ((connect-line (format "connect \"%s\"" host-name))
        (commands (mapconcat #'anyconnect--get-step-value  anyconnect-steps "\n")))
    (anyconnect--start-connection (concat connect-line commands "\n"))))

(provide 'anyconnect)
;;; anyconnect.el ends here
