# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`smartmet-test-db` is **not** a C++ project — it is a packaged PostgreSQL test fixture used by the rest of the SmartMet ecosystem. It ships:

1. Six PostgreSQL `pg_dump` custom-format dump files (`*.dump`) and a globals/roles SQL script (`globals.sql`).
2. Shell scripts that initialize a fresh PostgreSQL cluster from those dumps (`create-local-db.sh`, `test-local-db.sh`, `test-db-ctl.sh`).
3. Two RPMs: the base `smartmet-test-db` (scripts + dumps; database is **not** populated on install) and `smartmet-test-db-devel` (a prebuilt `pgdata` tree wrapped in a systemd service for use as a long-running test DB).

The six databases are: `authentication`, `avi`, `fminames`, `gis`, `icemap2storage_ro`, `iot_obs` (defined by the `DATABASES` variable in `Makefile`).

## Common commands

```bash
make                    # = `make all` — runs create-local-db.sh into ./test-database/
make test               # Rebuild ./test-database/ and run test-local-db.sh against it
make test-installed     # Same, but use the system-installed scripts in /usr/share/smartmet/test/db
make rpm                # Build both base and -devel RPMs via rpmbuild -tb
make clean              # Stop any running test cluster and remove ./test-database/
make dumps              # Re-dump all six databases from a live server at smartmet-test:5444
```

Run a single database against the dumps without rebuilding all six (only `avi` here):

```bash
./create-local-db.sh test-database pg_restore avi.dump
```

The third argument controls dump-loading: `pg_restore` (use `pg_restore` directly) or `collation_C` (init the cluster with `LC_ALL=C` instead of `en_US.UTF-8`). If neither keyword is given, dumps are piped through `postgis_restore.pl` to strip PostGIS objects before reload. Any further arguments are a whitelist of dump files; if empty, all six are loaded.

Control a built local cluster manually:

```bash
./test-db-ctl.sh test-database start    # or stop, status, restart, ...
```

## Port conventions

- **15444** — used by `create-local-db.sh` while building/restoring (avoids colliding with a running test DB).
- **5444** — used by `test-local-db.sh`, `test-db-ctl.sh`, and the installed `smartmet-test-db.service`. This is the port other SmartMet projects' test suites expect.

These differ on purpose: build-time work uses 15444 so it cannot interfere with an installed `-devel` service running on 5444.

## Roles and passwords

`globals.sql` is the source of truth for roles. Tests in *other* SmartMet repos hard-code these usernames/passwords, so do not rename or rotate them casually. Notable: `avi_user` has `search_path = avidb_bs_ro, public` and `TIME ZONE GMT` — both required by the `avi` plugin's tests (changing the timezone breaks ordering-sensitive `avi` tests).

## RPM packaging notes

- `BuildRequires`/`Requires`: `postgresql15-server`, `postgresql15-contrib`, `postgis36_15`. The build is pinned to PostgreSQL 15 + PostGIS 3.6; `create-local-db.sh` looks for `/usr/pgsql-15/bin/pg_ctl` first.
- The `-devel` subpackage's `%post` scriptlet untars `pgdata.tar.xz` into `/var/lib/smartmet-test-db/pgdata`, chowns it to `postgres:postgres`, and `systemctl enable --now smartmet-test-db`. Upgrades stop the service in `%pre` and restart in `%post`. When changing scriptlets, remember the install vs upgrade distinction (`$1 -eq 1` vs `$1 -eq 2`) — getting it wrong leaves stale `pgdata` from the prior version.
- The `testinstall` Make target asserts exact file counts (`*.sql=1`, `*.dump=6`, `*.sh=3`) installed under `/usr/share/smartmet/test/db/`. If you add or rename a top-level script/sql/dump, update this assertion.

## Updating dumps

`make dumps` connects to `smartmet-test:5444` as `postgres` and overwrites the six `*.dump` files in-place plus regenerates `globals.sql` via `pg_dumpall -g`. After regenerating, bump the version in `smartmet-test-db.spec` and add a changelog entry — the `-devel` RPM ships a binary `pgdata`, so dump changes require a new release for downstream test images to pick them up.

## CI

CircleCI builds and tests on `fmidev/smartmet-cibase-8` (RHEL8) only. The pipeline is `build-rhel8` → `test-rhel8` (installs the just-built RPM, runs `ci-build test`) → `upload-rhel8` (S3 sync to `fmi-smartmet-cicd-beta/centos8/`). There is no RHEL9 / cibase-10 job in this repo.
