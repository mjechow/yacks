# Changelog

## [4.3.2](https://github.com/mjechow/yacks/compare/4.3.1...4.3.2) (2026-04-30)


### Bug Fixes

* **lint:** enforce pre-commit for humans, skip for bots ([e065ba1](https://github.com/mjechow/yacks/commit/e065ba19e1894bfebecd819b34b9736ea41ef560))


### Reverts

* **ci:** restore GITHUB_TOKEN for release-please ([c8b0596](https://github.com/mjechow/yacks/commit/c8b0596e05407c0e612af74f707de3572f56cd8e))

## [4.3.1](https://github.com/mjechow/yacks/compare/4.3.0...4.3.1) (2026-04-29)


### Bug Fixes

* **ci:** use PAT for release-please to allow workflow triggers ([a4a3489](https://github.com/mjechow/yacks/commit/a4a348964efe2dad13869cef36e7791b6e8c1b7c))
* **lint:** re-add push trigger for release-please branch ([fbeea71](https://github.com/mjechow/yacks/commit/fbeea71fbfd7b2fed3163a380d9e3058337c4c97))
* **purge:** fix --purge-old aborting under pipefail and without tty ([c04dbba](https://github.com/mjechow/yacks/commit/c04dbba494e6cbc85a0dbdc145276fd6febc3416))

## [4.3.0](https://github.com/mjechow/yacks/compare/4.2.0...4.3.0) (2026-04-24)


### Features

* add --purge-old, short flags and --help ([b8dfcec](https://github.com/mjechow/yacks/commit/b8dfcec4f203ff2160435a5036b822bda54b69f2))
* **config:** disable SCTP, switch to USB_EHCI_HCD_PLATFORM ([6222826](https://github.com/mjechow/yacks/commit/622282610514bc58f2928eaf0187f39684b5ced5))

## [4.2.0](https://github.com/mjechow/yacks/compare/4.1.1...4.2.0) (2026-04-20)


### Features

* prompt to install kernel packages after successful build ([dd97d1c](https://github.com/mjechow/yacks/commit/dd97d1c7479337f6c3e644e046a499f9368b163a))


### Bug Fixes

* read kernel version from Makefile, use ls-remote for staleness check ([2bde287](https://github.com/mjechow/yacks/commit/2bde2872b40c450784d8432b73f9bc8a27eca65f))
