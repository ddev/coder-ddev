# Choosing a Template

coder.ddev.com offers four workspace templates. All of them include the same tools (DDEV, Docker, VS Code for Web, Git); they differ in what gets set up for you.

| Template           | Best for                                                                 | What is set up for you                                                                                          | Start here                                                                                          |
| ------------------ | ------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| **freeform**       | Your own projects in any framework DDEV supports; several projects at once | Nothing project-specific. You clone or create projects yourself; each listed project gets its own URL and app buttons. | [Freeform workspaces](../freeform/index.md)                                                          |
| **drupal-core**    | Drupal core development and core issue forks                             | A Drupal core checkout, installed site, issue fork branch if you choose one                                      | [Drupal issue picker](https://start.coder.ddev.com/drupal-issue) or [Drupal quickstart](../drupal/quickstart.md) |
| **drupal-contrib** | Working on a contrib module or theme from drupal.org                     | The project checkout, a Drupal site with the project enabled, issue fork branch if you choose one                | [Drupal issue picker](https://start.coder.ddev.com/drupal-issue)                                     |
| **canvas-migration** (experimental) | Bringing an existing website's design and content into Drupal CMS with Claude | A Drupal CMS site with Canvas, Storybook, and Claude Code connected to both through MCP | The template's **Docs** tab when you create the workspace; [Canvas AI Migrations](https://www.drupal.org/project/canvas_ai_migrations) |

## Rules of thumb

- **Working on a drupal.org issue?** Use the [issue picker](https://start.coder.ddev.com/drupal-issue). It detects core or contrib and fills in the right settings.
- **Migrating an existing site to Drupal CMS with Canvas?** Try **canvas-migration**. It is experimental, so expect changes.
- **Anything else** (a client site, a WordPress or Laravel app, a Drupal site that isn't core development, trying out a framework): use **freeform**.
- **Several related sites** (for example a front end and an API, or a multisite setup): use one **freeform** workspace with several [projects](../freeform/multiple-projects.md).
- **Want projects fully isolated from each other?** Create separate workspaces. Each workspace has its own Docker daemon and disk.
