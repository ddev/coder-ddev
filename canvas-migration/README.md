---
display_name: Drupal CMS Canvas Migration (Experimental)
description: Bring an existing website into Drupal CMS with Canvas, Storybook and Claude, ready to use in your browser.
icon: /icon/docker.svg
tags: [docker, drupal, migration, experimental]
---

# Drupal CMS Canvas Migration

> **Experimental:** this template is new. Its workflow and parameters may
> change between versions.

Bring an existing website's design and content into Drupal CMS with help from
Claude. Powered by [Canvas AI Migrations](https://www.drupal.org/project/canvas_ai_migrations),
this workspace gives you a place to build, review and refine your migration before
putting it into Drupal.

Everything runs in Coder, a cloud development workspace, with DDEV managing the
Drupal site. Open the editor, terminal and previews in your browser—no local
Docker or DDEV installation is needed.

## Features

- **Drupal CMS with Canvas Code Components.** Build reusable React components
  specifically for Drupal Canvas, ready to use when composing pages.
- **Storybook-first development.** Recreate and review components and page layouts
  in Storybook before bringing them into the Drupal site.
- **Design and content migration.** Carry across the source site's text, images
  and links as well as its appearance. Choose a close visual match or work to a
  design system while preserving the original content.
- **Connected AI tools.** Claude can use Drupal and Storybook through MCP, with
  skills for component development, content work and quality review.
- **Validation and accessibility checks.** The workflow includes code and Canvas
  schema checks, browser-based component tests, and review of the rendered pages.

## How a migration works

**Explore the source.** Start with `/building-ui`. Claude helps establish what you
want to migrate, how closely to match it, and whether to use an existing design
system.

**Build in Storybook.** Recreate the UI as Canvas Code Components, using the source
content and imagery. Preview layouts and component states, review the result,
and refine it before moving into Drupal.

**Bring it into Drupal.** With your approval, transfer the components and migrate
the content into the Drupal CMS site, then compose the Canvas pages. The workflow
covers the website's content and pages as well as the component library; it is not
a database copy of the original CMS.

**Check the finished pages.** Use `/qa-review` to compare the result with the source
in a real browser, including the Drupal rendering rather than only the Storybook
preview. Fix findings and repeat the checks before calling the migration complete.

## What gets checked

The supplied tools and QA skills support:

- **Code and component validation:** linting and type checks, Canvas schema
  validation, and Vitest component tests running in a browser through Playwright.
- **Content and visual accuracy:** text, images and links compared with the source;
  screenshots at desktop, tablet and mobile sizes; spacing, wrapping and overflow.
- **Behaviour:** navigation, menus, forms, hover states and animations, including
  behaviour during scrolling and with reduced motion enabled.
- **Accessibility:** axe-core checks covering WCAG 2.0 and 2.1 A/AA rules, plus
  browser checks of keyboard operation, focus visibility, headings, landmarks
  and accessible names.

These checks are part of the migration review, not something workspace creation
runs against a finished site. Automated checks help find issues; they do not
certify accessibility compliance.

## Start here

1. Create a workspace. Add the website you want to migrate if you know it;
   the source URL and output Git repository are both optional. With a source
   URL, switch on **Start a migration with /building-ui** to have Claude start
   on that site when you first sign in.
2. Open **Migration setup log** and wait for the status to say **ready**.
3. Open **Claude Code**, sign in with a supported Claude subscription, and check
   the Drupal and Storybook connections with `/mcp`.
4. Start with **`/building-ui`**. Tell Claude which site or design you want to
   recreate, and it will guide you through choosing how to build it.

Use the **Drupal project** button to view your site, **Storybook** to preview
components, and **VS Code Web** to edit the project. Claude is given guidance
about this workspace, DDEV and the configured MCP connections.

## Learn more

The [Canvas AI Migrations project page](https://www.drupal.org/project/canvas_ai_migrations#documentation)
explains the workflow and links to its documentation. The
[detailed Acquia Source guide](https://acquiasource.workflows-of-ai.com/) covers a
hosted Drupal target; this workspace provides its own Drupal CMS site in DDEV.

## Your workspace

Each workspace holds one migration. Stop it when you are finished and start it
again to continue; your files and database are preserved. Deleting it removes
that data, so save your work first.

The site and Storybook are private by default. Drupal starts with **admin / admin**;
change the password before enabling **Public Sharing**. Claude remote control and
skipping permission prompts are enabled by default; turn off the latter if you
prefer to approve actions individually.
