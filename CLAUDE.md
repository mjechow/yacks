# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Workflow

- Use GitHub Flow: create a feature branch for every change, commit there, open a PR to main
- Never commit directly to main

## Constraints

- Always document changes in README.md or the relevant file in english language

## Gotchas

- `CC="ccache gcc"` must be passed as a make variable (not just exported) so it propagates through `dpkg-buildpackage`.
- `./scripts/config` silently does nothing if a config option doesn't exist
  (renamed/removed between kernel versions). Always verify changes via the
  generated `.diff` file after `make olddefconfig`.
