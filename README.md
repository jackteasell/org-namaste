# org-namaste

Bridge between Emacs Org-mode and Asana. Pull tasks into Org headings, push headings back as tasks, and keep everything in sync.

## Requirements

- Emacs 27.1+
- Org-mode 9.0+

No external packages required — uses built-in `url.el` and `json.el`.

## Setup

### Standard Emacs

1. Clone the repo:

   ```sh
   git clone https://github.com/jackteasell/org-namaste.git
   ```

2. Copy the example config and fill in your details:

   ```sh
   cp org-namaste/.org-namaste.example.json ~/.org-namaste.json
   ```

   Edit `~/.org-namaste.json` with your actual values:

   ```json
   {
     "asana_token": "your_personal_access_token",
     "workspace_id": "your_workspace_id",
     "default_project_id": "your_project_id",
     "org_directory": "~/org-namaste/",
     "sync_on_open": false
   }
   ```

   **Get your Asana credentials:**
   - Generate a personal access token in [Asana Developer Console](https://app.asana.com/0/developer-console)
   - Find your workspace ID and project ID in Asana URLs (the long number in the URL)

3. Add to your Emacs config:

   ```elisp
   (add-to-list 'load-path "/path/to/org-namaste")
   (require 'org-namaste)
   ```

### Doom Emacs

1. Clone the repo directly into Doom's local packages directory:

   ```sh
   git clone https://github.com/jackteasell/org-namaste.git ~/.doom.d/local-packages/org-namaste
   ```

2. Add to `~/.doom.d/packages.el`:

   ```elisp
   (package! org-namaste)
   ```

3. Add to `~/.doom.d/config.el`:

   ```elisp
   (use-package! org-namaste
     :after org
     :config
     (add-hook 'org-mode-hook #'org-namaste-mode))
   ```

4. Run `doom sync` and restart Emacs

5. Create your config file:

   ```sh
   cp ~/.doom.d/local-packages/org-namaste/.org-namaste.example.json ~/.org-namaste.json
   ```

   Then edit `~/.org-namaste.json` with your Asana credentials (see above for how to get them)

## Usage

Enable the minor mode in any Org buffer:

```
M-x org-namaste-mode
```

### Keybindings

| Key       | Command                    | Description                          |
|-----------|----------------------------|--------------------------------------|
| `C-c n f` | `org-namaste-fetch-tasks`  | Fetch tasks from Asana into buffer   |
| `C-c n p` | `org-namaste-push-heading` | Push current heading to Asana        |
| `C-c n c` | `org-namaste-check-config` | Verify your config file is valid     |

### How tasks map to Org

Asana tasks become Org headings with `TODO`/`DONE` state. The Asana task ID is stored in a `:PROPERTIES:` drawer so syncing works in both directions:

```org
* TODO Write project proposal
:PROPERTIES:
:ASANA_GID: 1234567890
:END:
This is the task description from Asana.
```

## Config options

| Key                  | Description                                    |
|----------------------|------------------------------------------------|
| `asana_token`        | Your Asana personal access token               |
| `workspace_id`       | Your Asana workspace ID                        |
| `default_project_id` | Project to fetch tasks from by default         |
| `org_directory`      | Directory for synced Org files                 |
| `sync_on_open`       | Auto-fetch tasks when enabling the minor mode  |

The config file path defaults to `~/.org-namaste.json` but can be customized:

```elisp
(setq org-namaste-config-file "~/path/to/your/config.json")
```

## Status

This is an early-stage project. The foundation is in place — config management, Org<->Asana data conversion, async API wiring, and a minor mode with keybindings. Active development is ongoing.
