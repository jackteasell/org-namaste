;;; org-namaste.el --- Bridge between Org-mode and Asana -*- lexical-binding: t; -*-

;; Author: Jack Teasell
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1") (org "9.0"))
;; Keywords: org, asana, project-management

;;; Commentary:

;; org-namaste syncs Asana tasks with Org-mode headings.
;; Copy .org-namaste.example.json to ~/.org-namaste.json and
;; fill in your Asana personal access token and workspace ID.

;;; Code:

(require 'org)
(require 'url)
(require 'json)
(require 'org-namaste-config)

(defvar org-namaste-api-base "https://app.asana.com/api/1.0"
  "Base URL for the Asana REST API.")

;;; --- API helpers (stubbed for now) ---

(defun org-namaste--auth-header ()
  "Return the Authorization header value from config."
  (let ((token (org-namaste-config-get 'asana_token)))
    (when token
      (concat "Bearer " token))))

(defun org-namaste--api-request (endpoint callback &optional method payload)
  "Make an async request to Asana ENDPOINT.
CALLBACK receives the parsed JSON response.
METHOD defaults to GET. PAYLOAD is an alist sent as JSON for POST/PUT."
  (unless (org-namaste-config-valid-p)
    (error "org-namaste: invalid config. Check ~/.org-namaste.json"))
  (let* ((url (concat org-namaste-api-base endpoint))
         (url-request-method (or method "GET"))
         (url-request-extra-headers
          `(("Authorization" . ,(org-namaste--auth-header))
            ("Content-Type" . "application/json")
            ("Accept" . "application/json")))
         (url-request-data
          (when payload (encode-coding-string (json-encode payload) 'utf-8))))
    (url-retrieve
     url
     (lambda (_status)
       (goto-char url-http-end-of-headers)
       (let* ((json-object-type 'alist)
              (json-key-type 'symbol)
              (response (json-read)))
         (funcall callback response)))
     nil t)))

;;; --- Org conversion ---

(defun org-namaste--task-to-org (task &optional level)
  "Convert an Asana TASK alist to an Org heading string.
LEVEL is the heading depth (default 1)."
  (let* ((lvl (or level 1))
         (stars (make-string lvl ?*))
         (name (alist-get 'name task "Untitled"))
         (completed (alist-get 'completed task))
         (state (if completed "DONE" "TODO"))
         (notes (alist-get 'notes task))
         (gid (alist-get 'gid task))
         (due (alist-get 'due_on task)))
    (concat
     stars " " state " " name "\n"
     ":PROPERTIES:\n"
     ":ASANA_GID: " (or gid "") "\n"
     (when due (concat ":DEADLINE: <" due ">\n"))
     ":END:\n"
     (when (and notes (not (string-empty-p notes)))
       (concat notes "\n")))))

(defun org-namaste--org-heading-to-task ()
  "Parse the Org heading at point into an Asana-compatible alist."
  (save-excursion
    (org-back-to-heading t)
    (let* ((heading (org-get-heading t t t t))
           (state (org-get-todo-state))
           (completed (string= state "DONE"))
           (gid (org-entry-get (point) "ASANA_GID"))
           (deadline (org-entry-get (point) "DEADLINE"))
           (body (org-get-entry)))
      `((name . ,heading)
        (completed . ,completed)
        (gid . ,gid)
        (due_on . ,deadline)
        (notes . ,(string-trim (or body "")))))))

;;; --- Helper commands ---

(defun org-namaste-list-workspaces ()
  "List all available workspaces with their IDs.
Useful for finding your workspace_id for the config file."
  (interactive)
  (let ((token (org-namaste-config-get 'asana_token)))
    (unless token
      (error "org-namaste: asana_token not set in config"))
    (message "org-namaste: fetching workspaces...")
    (org-namaste--api-request
     "/workspaces"
     (lambda (response)
       (let ((workspaces (alist-get 'data response)))
         (if workspaces
             (progn
               (with-current-buffer (get-buffer-create "*org-namaste-workspaces*")
                 (erase-buffer)
                 (insert "Available Asana Workspaces:\n")
                 (insert "============================\n\n")
                 (dolist (ws (append workspaces nil))
                   (insert (format "Name: %s\nID:   %s\n\n"
                                   (alist-get 'name ws)
                                   (alist-get 'gid ws))))
                 (insert "\nCopy the ID value to your ~/.org-namaste.json as workspace_id")
                 (goto-char (point-min))
                 (display-buffer (current-buffer)))
               (message "org-namaste: workspaces listed in *org-namaste-workspaces* buffer"))
           (message "org-namaste: no workspaces found")))))))

(defun org-namaste-list-projects ()
  "List all projects in the configured workspace with their IDs.
Useful for finding your default_project_id for the config file."
  (interactive)
  (let ((workspace-id (org-namaste-config-get 'workspace_id)))
    (unless workspace-id
      (error "org-namaste: workspace_id not set in config"))
    (message "org-namaste: fetching projects...")
    (org-namaste--api-request
     (format "/workspaces/%s/projects" workspace-id)
     (lambda (response)
       (let ((projects (alist-get 'data response)))
         (if projects
             (progn
               (with-current-buffer (get-buffer-create "*org-namaste-projects*")
                 (erase-buffer)
                 (insert (format "Projects in workspace %s:\n" workspace-id))
                 (insert "============================\n\n")
                 (dolist (proj (append projects nil))
                   (insert (format "Name: %s\nID:   %s\n\n"
                                   (alist-get 'name proj)
                                   (alist-get 'gid proj))))
                 (insert "\nCopy the ID value to your ~/.org-namaste.json as default_project_id")
                 (goto-char (point-min))
                 (display-buffer (current-buffer)))
               (message "org-namaste: projects listed in *org-namaste-projects* buffer"))
           (message "org-namaste: no projects found")))))))

;;; --- Interactive commands ---

(defun org-namaste--validate-token (callback)
  "Validate the Asana token by calling /users/me. Calls CALLBACK with t/nil."
  (condition-case err
      (org-namaste--api-request
       "/users/me"
       (lambda (response)
         (if (alist-get 'data response)
             (funcall callback t)
           (funcall callback nil)))
       "GET")
    (error (funcall callback nil))))

(defun org-namaste--validate-workspace (workspace-id callback)
  "Validate WORKSPACE-ID exists. Calls CALLBACK with t/nil."
  (condition-case err
      (org-namaste--api-request
       (format "/workspaces/%s" workspace-id)
       (lambda (response)
         (if (alist-get 'data response)
             (funcall callback t)
           (funcall callback nil)))
       "GET")
    (error (funcall callback nil))))

(defun org-namaste--validate-project (project-id callback)
  "Validate PROJECT-ID exists. Calls CALLBACK with t/nil."
  (condition-case err
      (org-namaste--api-request
       (format "/projects/%s" project-id)
       (lambda (response)
         (if (alist-get 'data response)
             (funcall callback t)
           (funcall callback nil)))
       "GET")
    (error (funcall callback nil))))

(defun org-namaste-check-config ()
  "Verify that the config file is present and valid by testing against Asana API."
  (interactive)
  (org-namaste-load-config)

  ;; First check basic config validity
  (unless (org-namaste-config-valid-p)
    (error "org-namaste: config is missing or has placeholder values. See .org-namaste.example.json"))

  (let ((workspace-id (org-namaste-config-get 'workspace_id))
        (project-id (org-namaste-config-get 'default_project_id)))

    (message "org-namaste: validating token...")
    (org-namaste--validate-token
     (lambda (token-valid)
       (if (not token-valid)
           (error "org-namaste: Invalid Asana token. Check your asana_token in ~/.org-namaste.json")
         (message "org-namaste: ✓ token valid")

         (when workspace-id
           (message "org-namaste: validating workspace...")
           (org-namaste--validate-workspace
            workspace-id
            (lambda (workspace-valid)
              (if (not workspace-valid)
                  (error "org-namaste: Invalid workspace_id '%s'. Check ~/.org-namaste.json" workspace-id)
                (message "org-namaste: ✓ workspace valid")

                (when project-id
                  (message "org-namaste: validating project...")
                  (org-namaste--validate-project
                   project-id
                   (lambda (project-valid)
                     (if (not project-valid)
                         (error "org-namaste: Invalid default_project_id '%s'. Check ~/.org-namaste.json" project-id)
                       (message "org-namaste: ✓ project valid")
                       (message "org-namaste: All config values are valid!"))))))))))))))

(defun org-namaste-fetch-tasks ()
  "Fetch tasks from the default project and insert them as Org headings.
Inserts into current buffer at point."
  (interactive)
  (let ((project-id (org-namaste-config-get 'default_project_id)))
    (unless project-id
      (error "org-namaste: set default_project_id in your config"))
    (org-namaste--api-request
     (format "/projects/%s/tasks?opt_fields=name,completed,notes,due_on" project-id)
     (lambda (response)
       (let ((tasks (alist-get 'data response)))
         (if tasks
             (with-current-buffer (current-buffer)
               (save-excursion
                 (dolist (task (append tasks nil))
                   (insert (org-namaste--task-to-org task 1) "\n")))
               (message "org-namaste: inserted %d tasks" (length tasks)))
           (message "org-namaste: no tasks found")))))))

(defun org-namaste-push-heading ()
  "Push the current Org heading to Asana as a new task (stubbed).
Currently just shows what would be sent."
  (interactive)
  (let ((task (org-namaste--org-heading-to-task)))
    (message "org-namaste: would push task: %s" (json-encode task))))

;;; --- Minor mode ---

(defvar org-namaste-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c n f") #'org-namaste-fetch-tasks)
    (define-key map (kbd "C-c n p") #'org-namaste-push-heading)
    (define-key map (kbd "C-c n c") #'org-namaste-check-config)
    (define-key map (kbd "C-c n w") #'org-namaste-list-workspaces)
    (define-key map (kbd "C-c n j") #'org-namaste-list-projects)
    map)
  "Keymap for `org-namaste-mode'.")

;;;###autoload
(define-minor-mode org-namaste-mode
  "Minor mode for syncing Org headings with Asana tasks."
  :lighter " Namaste"
  :keymap org-namaste-mode-map
  (if org-namaste-mode
      (progn
        (org-namaste-load-config)
        (when (org-namaste-config-get 'sync_on_open)
          (org-namaste-fetch-tasks))
        (message "org-namaste-mode enabled"))
    (message "org-namaste-mode disabled")))

(provide 'org-namaste)
;;; org-namaste.el ends here
