# Freeform Workspaces

The **freeform** template is a general-purpose DDEV workspace. It doesn't set up any particular project for you. You bring your own code, or create a new project, and run it with DDEV exactly as you would on your own computer. Anything DDEV supports works: WordPress, Laravel, Symfony, Drupal sites, TYPO3, Craft CMS, Magento, Node.js, Python, static sites and more.

[Create a freeform workspace](https://coder.ddev.com/templates/coder/freeform/workspace?mode=manual){ .md-button .md-button--primary }

## What makes freeform different

- **Several projects in one workspace.** List the DDEV project names you plan to use, and each one gets its own URL and its own app buttons. DDEV's router sends each request to the right project. See [Multiple projects](multiple-projects.md).
- **Real HTTPS URLs for every project.** Each site is served at `https://<project>--<workspace>--<your-username>.coder.ddev.com`. Mailpit and xhgui get their own URLs too.
- **One setup command per project.** `ddev coder-setup` hooks a project into the workspace's routing. After that, `ddev start` keeps the routes up to date, including routes for add-on services.
- **Optional public sharing** of your sites, so you can show work-in-progress to someone without a Coder account. See [Sharing your site](sharing.md).
- **Optional Claude Code**, either as remote control from claude.ai/code or as a self-hosted runner. See [Claude Code](../workspaces/ai-tools.md).

## The short version

```bash
# In the workspace terminal (VS Code → Terminal → New Terminal)
git clone https://github.com/your-org/my-site.git ~/my-site
cd ~/my-site
ddev config --project-name=my-site    # must be one of the workspace's project names
ddev coder-setup                      # once per project
ddev start
```

Then click the **my-site** app button on the workspace page, or run `ddev launch`.

That's all there is to it. The rest of this section explains each step:

1. [Creating a freeform workspace](create.md): the settings you can choose.
2. [Your first project](first-project.md): a complete walkthrough.
3. [Multiple projects](multiple-projects.md): running several sites side by side.
4. [Project recipes](recipes.md): copy-and-paste setups for popular frameworks.
5. [Services and add-ons](services.md): Mailpit, xhgui, databases, Redis, Solr and other DDEV add-ons.
6. [Sharing your site](sharing.md): making a site public.
