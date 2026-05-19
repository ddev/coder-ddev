# Quickstart: Drupal Development Workspace Setup on coder.ddev.com

Cloud-hosted DDEV workspaces for Drupal core and contrib development. Full environment — Drupal core clone, running site, drush — ready when the startup script completes.

---

## 1. Log in or request access

Go to **[coder.ddev.com](https://coder.ddev.com)** and sign in with GitHub. You must belong to an approved GitHub organization to use coder.ddev.com.

---

## 2. Create a workspace

Pick one of the following two guided forms to either load a clean Drupal install, or work on an issue or contrib project.

<div class="cds-tile-grid cds-tile-grid--2">
  <article class="cds-tile cds-tile--featured">
    <div class="cds-tile__eyebrow">Recommended</div>
    <h2 class="cds-tile__title">Guided Drupal Issue picker</h2>
    <p class="cds-tile__desc">Get started from an issue fork or contrib project using <a href="https://github.com/amateescu/ddev-drupal-contrib"><code>ddev-drupal-contrib</code></a> (or <a href="https://github.com/amateescu/ddev-drupal-dev"><code>ddev-drupal-dev</code></a> for core issues).</p>
    <div class="cds-tile__actions">
      <a class="cds-btn cds-btn--primary" href="/drupal-issue">Drupal issue picker</a>
    </div>
  </article>

  <article class="cds-tile">
    <h2 class="cds-tile__title">Vanilla Drupal Core</h2>
    <p class="cds-tile__desc">Launch into Drupal core on a mainline 10.x, 11.x, or 12.x branch (no contrib modules or issue fork) using <a href="https://github.com/amateescu/ddev-drupal-dev"><code>ddev-drupal-dev</code> </a>conventional project structure.</p>
    <div class="cds-tile__actions">
      <a class="cds-btn cds-btn--secondary" href="/drupal-core">Drupal core picker</a>
    </div>
  </article>
</div>

<br>

On the form, select the appropriate Drupal version and install profile, then launch your workspace in Coder.

Inside Coder, you may be asked to "Confirm and Create" to proceed. Clicking "Cancel" drops you into a copy of the selected Coder Workspace template with read-only parameters. Modifying these parameters manually can result in unexpected behaviors and should be avoided. Instead start over on the guided form.

Wait for the startup script to complete. Watch progress in the **Logs** tab.

---

## 3. Open your environment

Once the workspace is running, click **DDEV Web** in the dashboard to open the Drupal site, or **VS Code** to open the editor (VS Code for Web, pre-pointed at `~/drupal-core`).

The running site has the profile you selected in step 2 pre-installed.

Admin credentials: `admin` / `admin`  (<em>Please modify if site is shared publicly.</em>)

---

## Code layout


### Drupal core development

```
~/drupal-core/           # Drupal core git clone — edit files here
├── core/                # Drupal core source
├── index.php            # Entry point
├── .ddev/               # DDEV config
└── composer.local.json  # Local dependencies (drush, dev modules)
```

Edit files directly in `~/drupal-core/` — changes are immediately reflected in the running site.

### Drupal contrib development

```
~/module_or_theme_name/  # Drupal contrib project repo — edit files here
├── web/                 # Drupal docroot.
├── web/core/            # Drupal core source. (installed via composer)
├── web/index.php        # Entry point
├── .ddev/               # DDEV config
└── composer.json        # Contrib project dependencies
```

Read more about folder structure and custom ddev contrib commands at [ddev-drupal-contrib](https://github.com/ddev/ddev-drupal-contrib).
---

## Common commands (run in VS Code terminal or `coder ssh <workspace>`)

```bash
# Get a one-time admin login link
ddev drush uli

# Clear cache
ddev drush cr

# Run Drupal tests (provided by ddev-drupal-dev add-on)
ddev phpunit core/modules/node

# Install a contrib module for development
ddev add-module token

# Open the site in your browser
ddev launch

# SSH into the web container
ddev ssh
```

---

## Working on a Drupal issue

On the [Guided Drupal Issue Picker](/drupal-issue), paste a drupal.org issue URL, issue number, or project URL — it auto-detects whether the issue is for Drupal core or a contrib module/theme, fetches the available branches, and opens a pre-configured workspace with the issue branch already checked out. Entering a project URL (e.g. `drupal.org/project/token`) or bare machine name launches a plain contrib dev workspace without a specific issue.

When working on an issue, the workspace surfaces issue info in several places:

- **Workspace resource page** — the `issue_url` metadata item links directly to the drupal.org issue
- **`~/WELCOME.txt`** — shows the issue number, title, and URL
- **Drupal site name** — set to `#NNNN: issue title` during install (visible in the site header)

To push your changes back:

```bash
cd ~/drupal-core  # or ~/module_or_theme_name

# ... make changes ...

# Push to the issue fork (remote is already added by the setup)
git push issue HEAD
```

Then create or update the issue’s associated merge request.

## First contribution workflow (manual)

If you prefer to set up a core feature branch manually:

```bash
# In the workspace terminal:
cd ~/drupal-core

# Create a branch
git checkout -b my-fix

# ... make changes ...

# Add a fork remote and push
git remote add fork https://git.drupalcode.org/issue/drupal-NNNNN.git
git push fork my-fix
```

Then create a merge request using the link from the output of the prior command.

---

## Workspace lifecycle

| Action | Effect |
|--------|--------|
| **Stop** workspace | Containers stop; your files persist on disk |
| **Start** workspace | No reinstall needed; picks up where you left off |
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

See also: [full getting-started guide](getting-started.md) · [DDEV docs](https://docs.ddev.com/) · [Drupal core contribution guide](https://www.drupal.org/contribute/development) · [ddev-drupal-dev add-on](https://github.com/amateescu/ddev-drupal-dev)
