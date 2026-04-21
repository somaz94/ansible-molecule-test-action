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

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
