# CLAUDE.md

<br/>

## Project Structure

- Composite GitHub Action (no Docker image — `runs.using: composite`)
- One-shot Ansible Molecule run: setup-python → install ansible + molecule + molecule-plugins[docker] → (optional galaxy/pip requirements) → `molecule test -s <scenario>`
- Driven by a single `distro` input; caller owns the matrix

<br/>

## Key Files

- `action.yml` — composite action (11 inputs, 2 outputs). All logic is inline `shell: bash` steps wrapping `actions/setup-python`
- `tests/fixtures/sample_role/` — minimal Ansible role with `molecule/default/` config; used by `ci.yml` and `use-action.yml`
- `cliff.toml` — git-cliff config for release notes
- `Makefile` — `lint` (dockerized yamllint), `test` (local molecule run), `fixtures`, `clean`

<br/>

## Build & Test

There is no local "build" — composite actions execute on the GitHub Actions runner.

```bash
make lint            # yamllint action.yml + workflows + fixtures
make test            # local molecule test against tests/fixtures/sample_role (needs docker)
make clean           # remove molecule caches
```

Requires Docker to run molecule locally. On macOS: Docker Desktop must be running.

<br/>

## Workflows

- `ci.yml` — `lint` (yamllint + actionlint) + `test-action` (matrix `ubuntu2404`/`rockylinux9` running the action via `uses: ./` against `tests/fixtures/sample_role`) + `ci-result` aggregator
- `release.yml` — git-cliff release notes + `softprops/action-gh-release` + `somaz94/major-tag-action` for `v1` sliding tag
- `use-action.yml` — post-release smoke test: `uses: somaz94/ansible-molecule-test-action@v1` against the same fixture, matrix `ubuntu2404`/`debian12`/`rockylinux9`
- `gitlab-mirror.yml`, `changelog-generator.yml`, `contributors.yml`, `dependabot-auto-merge.yml`, `issue-greeting.yml`, `stale-issues.yml` — standard repo automation

<br/>

## Release

Push a `vX.Y.Z` tag → `release.yml` runs → GitHub Release published → `v1` major tag updated → `use-action.yml` smoke-tests the published version against the fixture role.

<br/>

## Action Inputs

Required: `distro` (e.g., `ubuntu2404`, `rockylinux9`).

Tuning: `scenario` (default `default`), `python_version` (default `3.12`), `ansible_version`, `molecule_version`, `working_directory`, `extra_pip_packages`, `extra_apt_packages`, `galaxy_requirements`, `pip_requirements`, `verbose`.

See [README.md](README.md) for the full table.

<br/>

## Internal Flow

1. Validate inputs (`distro` non-empty, `working_directory` exists)
2. Install `extra_apt_packages` via `apt-get` (optional)
3. `actions/setup-python` with `pip` cache
4. `pip install` ansible + molecule (+ optional pins) + `molecule-plugins[docker]` + `docker` + `extra_pip_packages`
5. `ansible-galaxy install -r` when `galaxy_requirements` file exists
6. `pip install -r` when `pip_requirements` file exists
7. `molecule test -s <scenario>` with `MOLECULE_DISTRO=<distro>`; step summary + outputs written regardless of pass/fail, exit code propagated
