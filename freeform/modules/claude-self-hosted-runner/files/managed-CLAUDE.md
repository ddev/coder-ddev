# Reading GitHub from this workspace

The session's `gh` and GitHub MCP tools reach only the repositories attached
to the session. To read or search anything else on GitHub, use `gh-read`
instead of `add_repo`, WebFetch, or a clone. It runs the real `gh` with the
workspace owner's own GitHub login from Coder, and accepts only read
commands:

- `gh-read issue view 123 -R owner/repo --comments`, `gh-read pr view|diff|checks 45 -R owner/repo`
- `gh-read issue list|pr list -R owner/repo ...`, `gh-read run view|list -R owner/repo ...`
- `gh-read search issues|prs|code|commits|repos ...`
- `gh-read api <endpoint> [-X GET -f key=value] [--jq ...] [--paginate]`, and `gh-read api graphql` for queries

`gh-read --help` lists the rest. Use it for public repositories anywhere and
for private ones the owner can read. For anything that writes (comments,
reviews, pushes, labels), use the session's own `gh` or GitHub MCP tools,
within the repositories attached to the session.

If `gh-read` says there is no GitHub login in Coder, tell the user to link
GitHub at the URL it prints and carry on without it.
