# Changelog

## [5.1.0](https://github.com/mjechow/yacks/compare/5.0.1...5.1.0) (2026-06-07)


### Features

* add -l/--list option to show all installed kernels ([e6b3f8f](https://github.com/mjechow/yacks/commit/e6b3f8fd06c8502d274979237375b7e5847a4fad))

## [5.0.1](https://github.com/mjechow/yacks/compare/5.0.0...5.0.1) (2026-05-23)


### Bug Fixes

* **build:** stabilize ccache by pinning KBUILD_BUILD_TIMESTAMP to kernel commit ([4560b3a](https://github.com/mjechow/yacks/commit/4560b3a9b5f9b3152dd5222c949148b04aef7d6a))
* **fragments:** drop unused, wrong-family, and platform-specific drivers ([d214e78](https://github.com/mjechow/yacks/commit/d214e78e73425a59ab7e76d8d88c120c851ce13c))

## [5.0.0](https://github.com/mjechow/yacks/compare/4.5.1...5.0.0) (2026-05-20)


### ⚠ BREAKING CHANGES

* **gpu:** gpu-nvidia.config deleted; kernel no longer built with NVIDIA/nouveau support

### Features

* **gpu:** drop NVIDIA RTX 3070, switch to AMD RX 9070 ([3fc63d1](https://github.com/mjechow/yacks/commit/3fc63d1e2f81ea2d06c25fdb33370543772da619))

## [4.5.1](https://github.com/mjechow/yacks/compare/4.5.0...4.5.1) (2026-05-16)


### Bug Fixes

* **sound,gpu:** pin new AMDGPU/sound options from diff review ([#53](https://github.com/mjechow/yacks/issues/53)) ([9cec13c](https://github.com/mjechow/yacks/commit/9cec13ce6b5dd40d7d44d12bbacb4ff2d9ed3ab4))

## [4.5.0](https://github.com/mjechow/yacks/compare/4.4.0...4.5.0) (2026-05-16)


### Features

* **gpu:** add AMD RX 9070 (RDNA 4) support alongside RTX 3070 ([#51](https://github.com/mjechow/yacks/issues/51)) ([2c310b6](https://github.com/mjechow/yacks/commit/2c310b6ccb5a7e2786c59ce8cbf30abcb420e68e))

## [4.4.0](https://github.com/mjechow/yacks/compare/4.3.2...4.4.0) (2026-05-15)


### Features

* **storage:** update hardware profile to dual NVMe PCIe 5.0/4.0 setup ([c62e802](https://github.com/mjechow/yacks/commit/c62e8024fefafcdebb177f5416285bc2498f845a))

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
