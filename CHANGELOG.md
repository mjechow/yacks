# Changelog

## [5.4.0](https://github.com/mjechow/yacks/compare/5.3.0...5.4.0) (2026-09-05)


### Features

* **build:** apply patches from patches/ after the tree reset ([da9e542](https://github.com/mjechow/yacks/commit/da9e5425ad2416d640a1da7208c300a79cd6ac96))
* **cpu:** enable the Promontory 21 chipset temperature ([2a30da4](https://github.com/mjechow/yacks/commit/2a30da42ddf653843549597b19e33d19bb88fc45))
* **tools:** take a thread count for spread, measure it both ways ([127997c](https://github.com/mjechow/yacks/commit/127997c0028917ad3da5b30364674e25e37bf798))

## [5.3.0](https://github.com/mjechow/yacks/compare/5.2.0...5.3.0) (2026-09-03)


### Features

* **tools:** add the spread benchmark for LLC placement ([1560a29](https://github.com/mjechow/yacks/commit/1560a299112e8dbcac6076df1b694fb617aa7aab))


### Bug Fixes

* **cpu:** leave the Promontory 21 sensor off, it cannot bind here ([4796f51](https://github.com/mjechow/yacks/commit/4796f51bca4cfbd1ead807c2b1c1d987f8ef8f98))
* **fragments:** drop CONFIG_ATALK, removed in 7.2 ([08f2f8a](https://github.com/mjechow/yacks/commit/08f2f8a8d7315b2893e97fba9354c34d7879f0fe))


### Performance Improvements

* **base:** keep cache-aware load balancing off ([b62b52d](https://github.com/mjechow/yacks/commit/b62b52d83a5e2bd4b0da8ac09662368ef603f42f))

## [5.2.0](https://github.com/mjechow/yacks/compare/5.1.1...5.2.0) (2026-08-30)


### Features

* **base:** build NTSYNC in for Wine and Proton ([d265003](https://github.com/mjechow/yacks/commit/d2650036ed1ae17cc9bc6077666669150a33b134))
* **build:** warn about unknown Kconfig symbols in fragments ([cb915df](https://github.com/mjechow/yacks/commit/cb915df7662221bb5502f0d78c381fa4c23a3829))
* **sound:** drop HDA and ASoC, keep USB audio only ([4a9e8aa](https://github.com/mjechow/yacks/commit/4a9e8aa8c5223eef501290b8bf434e95ee17f799))
* **tools:** add knobbench for comparing runtime kernel knobs ([847fa90](https://github.com/mjechow/yacks/commit/847fa900c49a3d09e10dff87fc3b5dbdac57a36c))


### Bug Fixes

* **base:** disable unused KEXEC_HANDOVER ([86a0386](https://github.com/mjechow/yacks/commit/86a0386f8706d640c75dd1b3f86bed692f2177cd))
* **base:** sign all modules to clear the unsigned-module taint ([5c89236](https://github.com/mjechow/yacks/commit/5c892366dc7c74eb3662c2b5c9f2426b9e2f6070))
* **cpu:** pin the amd-pstate operating mode ([3c8dbda](https://github.com/mjechow/yacks/commit/3c8dbda6468c375f5ef80a35ee7be5409e925265))
* **fragments:** correct renamed and removed Kconfig symbols ([cd2b724](https://github.com/mjechow/yacks/commit/cd2b7244605f4105b142faf8122ce2911937aef0))
* **hardware:** disable the MMC stack and game controller drivers ([efe18b5](https://github.com/mjechow/yacks/commit/efe18b50363f807747bada947a25fc4bbf96acb0))


### Performance Improvements

* **base:** default transparent hugepages to always ([9c8c0c4](https://github.com/mjechow/yacks/commit/9c8c0c45846be98e0e0027f7e5f0fb592e17d7d9))

## [5.1.1](https://github.com/mjechow/yacks/compare/5.1.0...5.1.1) (2026-07-05)


### Bug Fixes

* **config:** disable PINCTRL_STMFX on desktop config ([2d5e762](https://github.com/mjechow/yacks/commit/2d5e7622a9f0a11e64227e13a8894415470a44af))

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
