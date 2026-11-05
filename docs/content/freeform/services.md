# Services and Add-ons

## Built in for every project

| Service       | How to open it                                                          | Notes                                                                                          |
| ------------- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| **Mailpit**   | **Mailpit (project)** app button, or `ddev launch -m`                    | Catches all email the project sends. Always private.                                           |
| **xhgui**     | **xhgui (project)** app button                                           | Profiling UI. Turn profiling on with `ddev xhgui on`. Always private.                         |
| **Database**  | `ddev mysql`, `ddev psql`, `ddev import-db`, `ddev export-db`, `ddev snapshot` | MariaDB by default; change it with `ddev config --database=...`.                         |

## Database tools

The quickest way to look at the database is the command line:

```bash
ddev mysql                              # interactive client (MariaDB/MySQL)
ddev mysql -e 'SHOW TABLES;'            # one query
ddev export-db --file=backup.sql.gz     # back up
ddev snapshot                           # fast snapshot you can restore with ddev snapshot restore
```

To use a desktop database client such as TablePlus or DBeaver, forward the database port to your computer with the Coder CLI. `ddev describe` shows the database's host port:

```bash
# On your computer
coder port-forward my-workspace --tcp 3306:<host-port-from-ddev-describe>
```

Then connect your client to `127.0.0.1:3306` with user `db`, password `db`, database `db`.

!!! note "Adminer and phpMyAdmin"
    On coder.ddev.com, freeform workspaces don't have an **Adminer** app button. You can still install a database UI add-on (for example `ddev add-on get ddev/ddev-adminer`); `ddev launch` then lists its URL as a forwarded port that only you can open.

## Other DDEV add-ons

Install add-ons from the [DDEV add-on registry](https://addons.ddev.com) the usual way:

```bash
ddev add-on get ddev/ddev-redis
ddev add-on get ddev/ddev-solr
ddev restart
```

The hook that `ddev coder-setup` installed runs after every start and adds routes for any new services that have a web interface. Run `ddev launch` to list all of the project's URLs, including those for add-ons.

- Add-on services with a web interface are reachable through forwarded-port URLs such as `https://8983--main--my-workspace--jdoe.coder.ddev.com`. These are private to you.
- `ddev describe` shows the new URLs after one more `ddev restart`; `ddev launch` shows them right away.

## Other ports

Anything listening on a port in the workspace (a dev server you run by hand, for example) can be opened from the workspace page with the **Ports** button, or from the command line:

```bash
# On your computer: make workspace port 5173 available as localhost:5173
coder port-forward my-workspace --tcp 5173
```
