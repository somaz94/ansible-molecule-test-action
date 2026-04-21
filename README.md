# ansible-molecule-test-action

[![CI](https://github.com/somaz94/ansible-molecule-test-action/actions/workflows/ci.yml/badge.svg)](https://github.com/somaz94/ansible-molecule-test-action/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Latest Tag](https://img.shields.io/github/v/tag/somaz94/ansible-molecule-test-action)](https://github.com/somaz94/ansible-molecule-test-action/tags)
[![Top Language](https://img.shields.io/github/languages/top/somaz94/ansible-molecule-test-action)](https://github.com/somaz94/ansible-molecule-test-action)
[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-Ansible%20Molecule%20Test%20Action-blue?logo=github)](https://github.com/marketplace/actions/ansible-molecule-test-action)

A composite GitHub Action that runs [Molecule](https://ansible.readthedocs.io/projects/molecule/) tests for an Ansible role or collection. Installs Python, Ansible, Molecule, and the Docker driver, then runs `molecule test` against the distro the caller specifies — typically from a matrix.

<br/>

## Features

- One action for the whole Molecule pipeline: **setup-python** → **install ansible + molecule + molecule-plugins[docker]** → **optional `ansible-galaxy install` / `pip install -r`** → **`molecule test`**
- Driven by a single `distro` input so the caller owns the matrix
- Version pins for Ansible and Molecule (`ansible_version`, `molecule_version`); empty = latest
- Optional `extra_pip_packages` and `extra_apt_packages` for scenario-specific tooling
- Writes a per-distro result to `$GITHUB_STEP_SUMMARY`
- Exposes `test_result` (`pass` / `fail`) and `tested_distro` outputs

<br/>

## Requirements

- **Runner OS**: `ubuntu-latest` (the Docker driver needs the runner's pre-installed Docker daemon — macOS and Windows runners are not supported).
- **Caller must run `actions/checkout`** before this action.
- **Python 3.10+** is recommended (default `3.12`).

<br/>

## Supported Target Distros

The `distro` input is exposed to Molecule as `MOLECULE_DISTRO` and is typically consumed by a `molecule.yml` like:

```yaml
platforms:
  - name: instance
    image: "geerlingguy/docker-${MOLECULE_DISTRO:-ubuntu2404}-ansible:latest"
    ...
```

Any tag published under [`geerlingguy/docker-*-ansible`](https://hub.docker.com/u/geerlingguy) works. The distros validated in this action's own CI / smoke test are:

| Distro tag | Family | Notes |
|------------|--------|-------|
| `ubuntu2204` | Ubuntu 22.04 (jammy) | common default |
| `ubuntu2404` | Ubuntu 24.04 (noble) | smoke-tested every release |
| `debian11` | Debian 11 (bullseye) | |
| `debian12` | Debian 12 (bookworm) | smoke-tested every release |
| `rockylinux9` | Rocky Linux 9 (EL9) | smoke-tested every release |

You can point at any other image by authoring your own `molecule.yml` — the action itself is distro-agnostic.

<br/>

## Quick Start

### Ansible role (matrix across distros)

```yaml
name: Molecule Test
on:
  push:
    branches: [main]
    paths:
      - "tasks/**"
      - "handlers/**"
      - "defaults/**"
      - "vars/**"
      - "meta/**"
      - "molecule/**"
      - "templates/**"
      - "files/**"
      - ".github/workflows/molecule-test.yml"
  pull_request:
  workflow_dispatch:

jobs:
  molecule:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        distro: [ubuntu2204, ubuntu2404, debian11, debian12, rockylinux9]
    steps:
      - uses: actions/checkout@v6
      - uses: somaz94/ansible-molecule-test-action@v1
        with:
          distro: ${{ matrix.distro }}
```

<br/>

### Ansible collection (with Galaxy requirements)

```yaml
- uses: actions/checkout@v6
- uses: somaz94/ansible-molecule-test-action@v1
  with:
    distro: ${{ matrix.distro }}
    galaxy_requirements: requirements.yml
    pip_requirements: requirements.txt
```

<br/>

## Usage

### Pin Ansible and Molecule versions

```yaml
- uses: somaz94/ansible-molecule-test-action@v1
  with:
    distro: ubuntu2404
    ansible_version: '9.5.1'
    molecule_version: '24.9.0'
```

<br/>

### Custom scenario (e.g., `idempotence` or `converge-only`)

```yaml
- uses: somaz94/ansible-molecule-test-action@v1
  with:
    distro: rockylinux9
    scenario: idempotence
```

<br/>

### Run against a sub-path (collection inside a monorepo)

```yaml
- uses: somaz94/ansible-molecule-test-action@v1
  with:
    distro: debian12
    working_directory: collections/somaz94.my_collection
```

<br/>

### Install extra tooling (pip or apt)

```yaml
- uses: somaz94/ansible-molecule-test-action@v1
  with:
    distro: ubuntu2404
    extra_pip_packages: 'pytest-testinfra yamllint'
    extra_apt_packages: 'sshpass'
```

<br/>

### Use the test result in a follow-up step

```yaml
- id: molecule
  uses: somaz94/ansible-molecule-test-action@v1
  with:
    distro: ${{ matrix.distro }}

- name: Publish result
  if: always()
  run: |
    echo "Distro: ${{ steps.molecule.outputs.tested_distro }}"
    echo "Result: ${{ steps.molecule.outputs.test_result }}"
```

<br/>

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `distro` | Target distro exposed to Molecule as `MOLECULE_DISTRO` (e.g., `ubuntu2404`, `rockylinux9`). | Yes | — |
| `scenario` | Molecule scenario name (`molecule test -s <scenario>`). | No | `default` |
| `python_version` | Python version for `actions/setup-python`. | No | `3.12` |
| `ansible_version` | pip pin for Ansible (e.g., `9.5.1`). Empty = latest. | No | `''` |
| `molecule_version` | pip pin for Molecule (e.g., `24.9.0`). Empty = latest. | No | `''` |
| `working_directory` | Role or collection root where `molecule/` lives. | No | `.` |
| `extra_pip_packages` | Space-separated extra pip packages. | No | `''` |
| `extra_apt_packages` | Space-separated extra apt packages installed before Molecule runs. | No | `''` |
| `galaxy_requirements` | Path (relative to `working_directory`) to a Galaxy `requirements.yml`. Skipped when the file does not exist. | No | `requirements.yml` |
| `pip_requirements` | Path (relative to `working_directory`) to a pip `requirements.txt`. Skipped when the file does not exist. | No | `requirements.txt` |
| `verbose` | Set `MOLECULE_VERBOSITY=1` and enable colored output. | No | `true` |

<br/>

## Outputs

| Output | Description |
|--------|-------------|
| `test_result` | `pass` or `fail` (matches the Molecule exit code). |
| `tested_distro` | Echo of the `distro` input for convenience in aggregated jobs. |

<br/>

## Permissions

The action itself needs no special permissions beyond what `actions/checkout` and `actions/setup-python` require. A typical caller:

```yaml
permissions:
  contents: read
```

Docker is pre-installed on `ubuntu-latest` runners, which is all the Molecule Docker driver requires.

<br/>

## How It Works

1. **Validate inputs** — fails fast when `distro` is empty or `working_directory` is missing.
2. **Install extra apt packages** (optional) — `sudo apt-get install` when `extra_apt_packages` is set.
3. **`actions/setup-python`** — installs the requested Python version.
4. **pip install** — `ansible` (+ optional version pin) and `molecule` + `molecule-plugins[docker]` + `docker` (+ optional version pin) + any `extra_pip_packages`.
5. **`ansible-galaxy install -r`** (optional) — runs when the referenced `requirements.yml` is present.
6. **`pip install -r`** (optional) — runs when the referenced `requirements.txt` is present.
7. **`molecule test -s <scenario>`** — executes in `working_directory` with `MOLECULE_DISTRO=<distro>` and colored output. Writes a per-distro summary to `$GITHUB_STEP_SUMMARY`; outputs are always populated (even on failure) so downstream jobs can aggregate.

<br/>

## Known Compatibility

### `molecule-plugins[docker]` + `ansible-core` 2.19

**Symptom** — `molecule test` fails in the `destroy` stage with:

> Conditional result (True) was derived from value of type 'str' at "\<environment variable 'HOME'\>". Conditionals must have a boolean result.

**Root cause** — `molecule-plugins[docker]`'s `destroy.yml` passes `"{{ lookup('env', 'HOME') }}"` (a string) to `when:`, which `ansible-core` 2.19+ rejects because conditionals must be booleans.

**Workaround** — Pin `ansible-core` in your repo's `requirements.txt`:

```text
ansible-core>=2.15,<2.19
```

This action auto-runs `pip install -r requirements.txt` in the `working_directory`, so the pin takes effect without further wiring.

**Tracking & exit plan**

- Upstream: [`ansible/molecule-plugins`](https://github.com/ansible/molecule-plugins/issues) — watch for a release that makes the `destroy.yml` conditional a real boolean.
- Once fixed, relax the pin to `ansible-core>=2.19.X,<3.0` (X = first fixed minor) and re-run CI.
- Dependabot note: the repos that consume this action currently manage only the `github-actions` ecosystem, so the `ansible-core<2.19` cap is not auto-touched. Enabling Dependabot's `pip` ecosystem won't help relax the cap (Dependabot respects but does not widen version specifiers) and risks conflicting PRs if future `ansible-lint` / `molecule` releases require `ansible-core>=2.19`. Prefer a periodic manual review (e.g., quarterly) of the pin.

<br/>

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
