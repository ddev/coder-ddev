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

## First contribution workflow

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
