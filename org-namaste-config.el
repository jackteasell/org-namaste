;;; org-namaste-config.el --- Configuration for org-namaste -*- lexical-binding: t; -*-

;; Load and manage org-namaste configuration from a JSON file.

;;; Code:

(require 'json)

(defgroup org-namaste nil
  "Sync Asana tasks with Org-mode."
  :group 'org
  :prefix "org-namaste-")

(defcustom org-namaste-config-file "~/.org-namaste.json"
  "Path to the org-namaste JSON config file."
  :type 'string
  :group 'org-namaste)

(defvar org-namaste--config nil
  "Cached config alist loaded from the config file.")

(defun org-namaste-load-config ()
  "Load config from `org-namaste-config-file'. Returns the config alist."
  (let ((path (expand-file-name org-namaste-config-file)))
    (if (file-exists-p path)
        (condition-case err
            (let ((json-object-type 'alist)
                  (json-key-type 'symbol))
              (setq org-namaste--config
                    (json-read-file path))
              (message "org-namaste: config loaded from %s" path)
              org-namaste--config)
          (error
           (message "org-namaste: failed to load config: %s" (error-message-string err))
           nil))
      (message "org-namaste: config file not found at %s. Copy .org-namaste.example.json to %s"
               path path)
      nil)))

(defun org-namaste-config-get (key &optional default)
  "Get KEY from the loaded config. Returns DEFAULT if not found.
Loads config from disk if not already loaded."
  (unless org-namaste--config
    (org-namaste-load-config))
  (if org-namaste--config
      (let ((val (alist-get key org-namaste--config)))
        (if (and val (not (equal val "")))
            val
          default))
    default))

(defun org-namaste-config-valid-p ()
  "Return t if the config has the minimum required fields."
  (and (org-namaste-config-get 'asana_token)
       (not (string= (org-namaste-config-get 'asana_token)
                      "YOUR_ASANA_PERSONAL_ACCESS_TOKEN"))
       (org-namaste-config-get 'workspace_id)
       (not (string= (org-namaste-config-get 'workspace_id)
                      "YOUR_WORKSPACE_ID"))))

(provide 'org-namaste-config)
;;; org-namaste-config.el ends here
