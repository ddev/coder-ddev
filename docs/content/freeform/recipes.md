# Project Recipes

These recipes create a new project from scratch in a freeform workspace. They follow DDEV's [CMS quickstarts](https://docs.ddev.com/en/stable/users/quickstart/) with the one extra step that a workspace needs: `ddev coder-setup`.

Each recipe assumes the project name is registered in the workspace's **DDEV project names** (see [Creating a workspace](create.md#ddev-project-names)). Replace `my-site` with your project name.

!!! tip "The pattern is always the same"
    `ddev config --project-name=<name> ...`, then `ddev coder-setup`, then `ddev start`. For any framework not listed here, use the matching DDEV quickstart and add `ddev coder-setup` before `ddev start`.

## WordPress

```bash
mkdir ~/my-site && cd ~/my-site
ddev config --project-name=my-site --project-type=wordpress
ddev coder-setup
ddev start
ddev wp core download
ddev wp core install --url='$DDEV_PRIMARY_URL' --title='My site' \
  --admin_user=admin --admin_password=admin --admin_email=admin@example.com
ddev launch /wp-admin/
```

!!! note "WordPress site URL"
    WordPress stores its own URL in the database. DDEV sets `WP_HOME` and `WP_SITEURL` for the project's `*.ddev.site` address, which isn't reachable through the workspace. If links or redirects point at `*.ddev.site`, set both to the workspace URL that `ddev launch` shows, in `wp-config.php` before DDEV's settings include, or with `ddev wp option update home <url>` and `ddev wp option update siteurl <url>`.

## Laravel

```bash
mkdir ~/my-site && cd ~/my-site
ddev config --project-name=my-site --project-type=laravel --docroot=public
ddev coder-setup
ddev start
ddev composer create-project laravel/laravel .
ddev launch
```

## Symfony

```bash
mkdir ~/my-site && cd ~/my-site
ddev config --project-name=my-site --project-type=symfony --docroot=public
ddev coder-setup
ddev start
ddev composer create-project symfony/skeleton .
ddev launch
```

## Drupal site

For a Drupal *site* (not Drupal core development, which has its [own template](../drupal/quickstart.md)):

```bash
mkdir ~/my-site && cd ~/my-site
ddev config --project-name=my-site --project-type=drupal11 --docroot=web
ddev coder-setup
ddev start
ddev composer create-project drupal/recommended-project .
ddev composer require drush/drush
ddev drush site:install --account-name=admin --account-pass=admin -y
ddev launch
```

Use `ddev drush uli` for a one-time login link; open it through `ddev launch` or replace the host with your workspace URL.

## Drupal CMS

```bash
mkdir ~/my-site && cd ~/my-site
ddev config --project-name=my-site --project-type=drupal11 --docroot=web
ddev coder-setup
ddev start
ddev composer create-project drupal/cms .
ddev launch
```

## TYPO3

```bash
mkdir ~/my-site && cd ~/my-site
ddev config --project-name=my-site --project-type=typo3 --docroot=public
ddev coder-setup
ddev start
ddev composer create-project typo3/cms-base-distribution .
ddev exec touch public/FIRST_INSTALL
ddev launch /typo3/install.php
```

## Craft CMS

```bash
mkdir ~/my-site && cd ~/my-site
ddev config --project-name=my-site --project-type=craftcms --docroot=web
ddev coder-setup
ddev start
ddev composer create-project craftcms/craft .
ddev launch
```

## Static HTML or plain PHP

```bash
mkdir -p ~/my-site/public && cd ~/my-site
echo '<?php phpinfo();' > public/index.php
ddev config --project-name=my-site --project-type=php --docroot=public
ddev coder-setup
ddev start
ddev launch
```

## Node.js app

DDEV can run a Node.js server in its web container with `web_extra_daemons` and `web_extra_exposed_ports`. A minimal example with Express:

```bash
mkdir ~/my-site && cd ~/my-site
ddev config --project-name=my-site --project-type=generic --webserver-type=generic
ddev coder-setup
cat > .ddev/config.node.yaml <<'YAML'
web_extra_daemons:
  - name: node
    command: "node server.js"
    directory: /var/www/html
web_extra_exposed_ports:
  - name: node
    container_port: 3000
    http_port: 80
    https_port: 443
YAML
ddev start
ddev npm init -y
ddev npm install express
cat > server.js <<'JS'
const app = require('express')();
app.get('/', (req, res) => res.send('Hello from DDEV on Coder'));
app.listen(3000);
JS
ddev restart
ddev launch
```

See DDEV's documentation on [extra daemons and exposed ports](https://docs.ddev.com/en/stable/users/extend/customization-extendibility/) for more.

## Front-end dev servers (Vite and friends)

A dev server running inside the web container needs to know the public URL it is served from. `ddev coder-setup` puts these variables into the web container for that purpose: `CODER`, `CODER_AGENT_URL`, `CODER_WORKSPACE_NAME`, `CODER_WORKSPACE_OWNER_NAME`, `CODER_WORKSPACE_AGENT_NAME` and `VSCODE_PROXY_URI`. Use them in your dev server's configuration to allow the workspace's hostname and to set the HMR host. See the [URL patterns reference](../reference/coder-url-patterns.md) for how the hostnames are built, and DDEV's [Vite documentation](https://docs.ddev.com/en/stable/users/usage/vite/) for a general Vite setup.
