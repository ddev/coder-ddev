# Blog Post Update Draft: coder.ddev.com Org-Gated Signup

**Target file**: `ddev/ddev.com/src/content/blog/coder-ddev-com-announcement.md`
**Action**: Apply these section replacements to the blog post, then open a PR to `ddev/ddev.com`

---

## Section: "Log In with GitHub" — Replace existing content

Find the section in the blog post that explains GitHub login. Replace the existing content of that section with the following:

---

### Log In with GitHub

Access to coder.ddev.com requires a GitHub account. Sign in using the **Sign in with GitHub** button — no separate Coder account registration is needed.

**Who has access:**

- Members of the [ddev](https://github.com/ddev) GitHub organization
- Members of organizations that sponsor DDEV at $100+/month (see the [DDEV sponsors page](https://ddev.com/support-ddev/))
- Individuals approved by the DDEV maintainers

If you are a `ddev` org member or your organization is a $100+/month sponsor, you can sign in immediately — no request needed.

---

## Section: Access Restriction and Request Path — Add after "Log In with GitHub"

Add the following as a new paragraph or subsection immediately after the "Log In with GitHub" section:

---

### Requesting Access

If you do not have access through one of the paths above, you can request it by opening an issue in the [coder-ddev-com/access-requests](https://github.com/coder-ddev-com/access-requests) repository on GitHub. Include your GitHub username and a brief description of how you plan to use the environment.

The DDEV maintainers review requests and add approved users to the `coder-ddev-com` GitHub organization. Once added, you can sign in immediately — no server restart needed on our end.

---

## Section: Sponsor Org Access — Add to "Sponsors" or "Support DDEV" section

If the blog post has a section mentioning DDEV sponsors, add the following sentence or short paragraph. If no such section exists, add it as a standalone callout near the end of the post:

---

**Sponsor org access**: Organizations that sponsor DDEV at $100+/month receive access as an org-level benefit — all members of a sponsor's GitHub organization can sign in to coder.ddev.com without individual enrollment. See the [DDEV sponsors page](https://ddev.com/support-ddev/) if your organization is interested in sponsoring.

---

**Note for operator**: If the blog post already has a sponsors callout, integrate this sentence rather than adding a duplicate section.
