# Quickstart: Drupal Core Development on coder.ddev.com

Cloud-hosted DDEV workspaces for Drupal core development. Full environment — Drupal core clone, running site, drush — ready in ~30 seconds.

[![Open in Coder](https://coder.ddev.com/open-in-coder.svg)](https://coder.ddev.com/templates/coder/drupal-core/workspace?mode=manual)

---

## 1. Log in

Go to **[coder.ddev.com](https://coder.ddev.com)** and sign in with GitHub.

---

## 2. Create a workspace

Click the button above, or go to **Create Workspace** → select the **drupal-core** template → click **Create Workspace**.

Wait ~30 seconds for the startup script to complete. Watch progress in the **Logs** tab.

---

## 3. Open your environment

Once the workspace is running, click **DDEV Web** in the dashboard to open the Drupal site, or **VS Code** to open the editor (VS Code for Web, pre-pointed at `~/drupal-core`).

The running site has the Umami demo profile installed. Admin credentials: `admin` / `admin`.

---

## Code layout

```
~/drupal-core/
├── repos/drupal/     # Drupal core git clone — edit files here
│   └── core/
├── web/              # Web docroot (core/ symlinked from repos/drupal/)
├── .ddev/            # DDEV config
└── vendor/           # Composer-managed dependencies
```

Make your changes in `repos/drupal/` — they are immediately reflected in the running site.

---

## Common commands (run in VS Code terminal or `coder ssh <workspace>`)

```bash
# Get a one-time admin login link
ddev drush uli

# Clear cache
ddev drush cr

# Run Drupal tests (from repos/drupal/)
ddev exec phpunit web/core/tests/...

# Open the site in your browser
ddev launch

# SSH into the web container
ddev ssh
```

---

## Working on a Drupal issue

The fastest way: use the **[Drupal Issue Picker](https://start.coder.ddev.com/drupal-issue)**. Paste a drupal.org issue URL or bare issue number — it fetches the available branches, lets you pick one, and opens a pre-configured workspace with the issue branch already checked out and all Composer dependencies resolved for that branch.

When working on an issue, the workspace surfaces issue info in several places:

- **Workspace resource page** — the `issue_url` metadata item links directly to the drupal.org issue
- **`~/WELCOME.txt`** — shows the issue number, title, and URL
- **Drupal site name** — set to `#NNNN: issue title` during install (visible in the site header)

To push your changes back:

```bash
cd ~/drupal-core/repos/drupal

# ... make changes ...

# Push to the issue fork (remote is already added by the setup)
git push issue HEAD
```

Then create or update the merge request on [drupal.org](https://www.drupal.org/project/drupal).

## First contribution workflow (manual)

If you prefer to set up manually:

```bash
# In the workspace terminal:
cd ~/drupal-core/repos/drupal

# Create a branch
git checkout -b my-fix

# ... make changes ...

# Add a fork remote and push
git remote add fork https://git.drupalcode.org/issue/drupal-NNNNN.git
git push fork my-fix
```

Then create a merge request on [drupal.org](https://www.drupal.org/project/drupal).

---

## Workspace lifecycle

| Action | Effect |
|--------|--------|
| **Stop** workspace | Containers stop; your files persist on disk |
| **Start** workspace | DDEV resumes in ~15 seconds; no reinstall needed |
| **Delete** workspace | All data deleted permanently |

---

## Troubleshooting

```bash
# Check setup status
cat ~/SETUP_STATUS.txt

# View setup log
tail -50 /tmp/drupal-setup.log

# Check DDEV status
ddev describe
```

See also: [full getting-started guide](getting-started.md) · [DDEV docs](https://docs.ddev.com/) · [Drupal core contribution guide](https://www.drupal.org/contribute/development)
