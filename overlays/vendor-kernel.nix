let
  # are drm-rp1-depends-on-instead-of-select-MFD_RP1 and
  # iommu-bcm2712-don-t-allow-building-as-module relevant only for RPi3?
  # see https://github.com/NixOS/nixpkgs/commit/bb51848e23465846f5823d1bacbed808a4469fcd
  drm-rp1-depends-on-instead-of-select-MFD_RP1 = super: {
    # Fix "WARNING: unmet direct dependencies detected for MFD_RP1", and
    # subsequent build failure.
    # https://github.com/NixOS/nixpkgs/pull/268280#issuecomment-1911839809
    # https://github.com/raspberrypi/linux/pull/5900
    name = "drm-rp1-depends-on-instead-of-select-MFD_RP1.patch";
    patch = super.fetchpatch {
      url = "https://github.com/peat-psuwit/rpi-linux/commit/6de0bb51929cd3ad4fa27b2a421a2af12e6468f5.patch";
      hash = "sha256-9pHcbgWTiztu48SBaLPVroUnxnXMKeCGt5vEo9V8WGw=";
    };
  };
  iommu-bcm2712-don-t-allow-building-as-module = super: {
    # Fix `ERROR: modpost: missing MODULE_LICENSE() in <...>/bcm2712-iommu.o`
    # by preventing such code from being built as module.
    # https://github.com/NixOS/nixpkgs/pull/284035#issuecomment-1913015802
    # https://github.com/raspberrypi/linux/pull/5910
    name = "iommu-bcm2712-don-t-allow-building-as-module.patch";
    patch = super.fetchpatch {
      url = "https://github.com/peat-psuwit/rpi-linux/commit/693a5e69bddbcbe1d1b796ebc7581c3597685b1b.patch";
      hash = "sha256-8BYYQDM5By8cTk48ASYKJhGVQnZBIK4PXtV70UtfS+A=";
    };
  };

  gpio-pwm_-_pwm_apply_might_sleep = super: {
    name = "gpio-pwm_-_pwm_apply_might_sleep.patch";
    patch = super.fetchpatch {
      url = "https://github.com/peat-psuwit/rpi-linux/commit/879f34b88c60dd59765caa30576cb5bfb8e73c56.patch";
      hash = "sha256-HlOkM9EFmlzOebCGoj7lNV5hc0wMjhaBFFZvaRCI0lI=";
    };
  };
  ir-rx51_-_pwm_apply_might_sleep = super: {
    name = "ir-rx51_-_pwm_apply_might_sleep.patch";
    patch = super.fetchpatch {
      url = "https://github.com/peat-psuwit/rpi-linux/commit/23431052d2dce8084b72e399fce82b05d86b847f.patch";
      hash = "sha256-UDX/BJCJG0WVndP/6PbPK+AZsfU3vVxDCrpn1kb1kqE=";
    };
  };

  linux_argsOverride = { modDirVersion,tag,srcHash
                       , structuredExtraConfig ? {}, kernelPatches ? [] }: super: rec {
    inherit modDirVersion tag structuredExtraConfig kernelPatches;

    version = "${modDirVersion}-${tag}";
    src = super.fetchFromGitHub {
      owner = "raspberrypi";
      repo = "linux";
      rev = tag;
      hash = srcHash;
    };
  };
  # only for RPI5
  linux_v6_6_74_cfg_argsOverride = super: linux_argsOverride {
    # https://github.com/raspberrypi/linux/releases/tag/stable_20250127
    modDirVersion = "6.6.74";
    tag = "stable_20250127";
    srcHash = "sha256-17PrkPUGBKU+nO40OP+O9dzZeCfRPlKnnk/PJOGamU8=";
    structuredExtraConfig = with super.lib.kernel; {
      ## generated from
      ## https://github.com/RPi-Distro/linux-packaging/tree/0f16c6016c8dfad65e72609257c956c955c69843

      # Content of file: config-arm64-rpi/config
      # CRYPTO_AES = module ; # =yes in nixos;
      # CRYPTO_SHA512 = module ; # =yes in nixos;
      NET_CLS_BPF = yes ; # =module in nixos;
      PREEMPT = yes;
      # Content of file: config-arm64-rpi/config.2712
      # LOCALVERSION = "-v8-16k" ; # ="" in nixos;

      # Content of file: config-featureset-rpi/config
      # BINFMT_MISC = module ; # =yes in nixos;
      CMA_SIZE_MBYTES = 5 ; # =32 in nixos;
      CPU_FREQ_DEFAULT_GOV_ONDEMAND = yes;
      # DRM = module ; # =yes in nixos;
      F2FS_FS = yes ; # =module in nixos;
      FB_SIMPLE = yes;
      # IKCONFIG = module ; # =yes in nixos;
      # IPV6 = module ; # =yes in nixos;
      IP_PNP = yes;
      IP_PNP_DHCP = yes;
      IP_PNP_RARP = yes;
      LOGO = yes;
      NFS_FS = yes ; # =module in nixos;
      NFS_V4 = yes ; # =module in nixos;
      NLS_CODEPAGE_437 = yes ; # =module in nixos;
      NTFS_FS = module;
      NTFS_RW = yes;
      ROOT_NFS = yes;
      UEVENT_HELPER = yes;
      USB_SERIAL = module ; # =yes in nixos;
      # USB_SERIAL = module ; # =yes in nixos;

      # Content of file: config-featureset-rt/config
      PREEMPT_RT = yes;
      RCU_EXPERT = yes;
      HWLAT_TRACER = yes;
      OSNOISE_TRACER = yes;
      TIMERLAT_TRACER = yes;

      # https://www.kernelconfig.io/
      # see also for PREEMPT, RT:
      # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/os-specific/linux/kernel/linux-rt-6.6.nix#L50

    };
  } super;
  linux_v6_6_74_argsOverride = super: linux_argsOverride {
    # https://github.com/raspberrypi/linux/releases/tag/stable_20250127
    modDirVersion = "6.6.74";
    tag = "stable_20250127";
    srcHash = "sha256-17PrkPUGBKU+nO40OP+O9dzZeCfRPlKnnk/PJOGamU8=";
    structuredExtraConfig = with super.lib.kernel; {
      # Workaround https://github.com/raspberrypi/linux/issues/6198
      # Needed because NixOS 24.05+ sets DRM_SIMPLEDRM=y which pulls in
      # DRM_KMS_HELPER=y.
      # BACKLIGHT_CLASS_DEVICE = yes;
    };
    kernelPatches = builtins.map (p: p super) [
      # Fix compilation errors due to incomplete patch backport.
      # https://github.com/raspberrypi/linux/pull/6223
      # gpio-pwm_-_pwm_apply_might_sleep
      # ir-rx51_-_pwm_apply_might_sleep
    ];
  } super;
  linux_v6_6_51_argsOverride = super: linux_argsOverride {
    # https://github.com/raspberrypi/linux/releases/tag/stable_20240529
    modDirVersion = "6.6.51";
    tag = "stable_20241008";
    srcHash = "sha256-phCxkuO+jUGZkfzSrBq6yErQeO2Td+inIGHxctXbD5U=";
    structuredExtraConfig = with super.lib.kernel; {
      # Workaround https://github.com/raspberrypi/linux/issues/6198
      # Needed because NixOS 24.05+ sets DRM_SIMPLEDRM=y which pulls in
      # DRM_KMS_HELPER=y.
      # BACKLIGHT_CLASS_DEVICE = yes;
    };
    kernelPatches = builtins.map (p: p super) [
      # Fix compilation errors due to incomplete patch backport.
      # https://github.com/raspberrypi/linux/pull/6223
      # gpio-pwm_-_pwm_apply_might_sleep
      # ir-rx51_-_pwm_apply_might_sleep
    ];
  } super;
  linux_v6_6_31_argsOverride = super: linux_argsOverride {
    # https://github.com/raspberrypi/linux/releases/tag/stable_20240529
    modDirVersion = "6.6.31";
    tag = "stable_20240529";
    srcHash = "sha256-UWUTeCpEN7dlFSQjog6S3HyEWCCnaqiUqV5KxCjYink=";
    structuredExtraConfig = with super.lib.kernel; {
      # Workaround https://github.com/raspberrypi/linux/issues/6198
      # Needed because NixOS 24.05+ sets DRM_SIMPLEDRM=y which pulls in
      # DRM_KMS_HELPER=y.
      BACKLIGHT_CLASS_DEVICE = yes;
    };
    kernelPatches = builtins.map (p: p super) [
      # Fix compilation errors due to incomplete patch backport.
      # https://github.com/raspberrypi/linux/pull/6223
      gpio-pwm_-_pwm_apply_might_sleep
      ir-rx51_-_pwm_apply_might_sleep
    ];
  } super;
  linux_v6_6_28_argsOverride = super: linux_argsOverride {
    # https://github.com/raspberrypi/linux/releases/tag/stable_20240423
    modDirVersion = "6.6.28";
    tag = "stable_20240423";
    srcHash = "sha256-mlsDuVczu0e57BlD/iq7IEEluOIgqbZ+W4Ju30E/zhw=";
    structuredExtraConfig = with super.lib.kernel; {
      GPIO_PWM = no;
    };
  } super;
  linux_v6_1_73_argsOverride = super: linux_argsOverride {
    # https://github.com/raspberrypi/linux/releases/tag/stable_20240124
    modDirVersion = "6.1.73";
    tag = "stable_20240124";
    srcHash = "sha256-P4ExzxWqZj+9FZr9U2tmh7rfs/3+iHEv0m74PCoXVuM=";
    kernelPatches = builtins.map (p: p super) [
      drm-rp1-depends-on-instead-of-select-MFD_RP1
      iommu-bcm2712-don-t-allow-building-as-module
    ];
  } super;
  linux_v6_1_63_argsOverride = super: linux_argsOverride {
    # https://github.com/raspberrypi/linux/releases/tag/stable_20231123
    modDirVersion = "6.1.63";
    tag = "stable_20231123";
    srcHash = "sha256-4Rc57y70LmRFwDnOD4rHoHGmfxD9zYEAwYm9Wvyb3no=";
    kernelPatches = builtins.map (p: p super) [
      drm-rp1-depends-on-instead-of-select-MFD_RP1
      iommu-bcm2712-don-t-allow-building-as-module
    ];
  } super;

  linuxArgsOverride = {
    "6_6_74_cfg" = linux_v6_6_74_cfg_argsOverride;
    "6_6_74" = linux_v6_6_74_argsOverride;
    "6_6_51" = linux_v6_6_51_argsOverride;
    "6_6_31" = linux_v6_6_31_argsOverride;
    "6_6_28" = linux_v6_6_28_argsOverride;
    "6_1_73" = linux_v6_1_73_argsOverride;
    "6_1_63" = linux_v6_1_63_argsOverride;
  };

  mkLinuxFor = super: version: models: let
    linuxVersionForModel = rpiModel: {
      # in nixpkgs this is also in pkgs.linuxKernel.packages.<...>
      # see also https://github.com/NixOS/nixos-hardware/pull/927
      # linux_rpi4_v6_6_28 = super.linux_rpi4.override {
      #   argsOverride = linux_v6_6_28_argsOverride super;
      # };

      # as in https://github.com/NixOS/nixpkgs/blob/master/pkgs/top-level/linux-kernels.nix#L91
      "linux_rpi${rpiModel}_v${version}" = super.callPackage ../pkgs/linux-rpi.nix {
        argsOverride = linuxArgsOverride.${version} super;
        kernelPatches = with super.kernelPatches; [
          bridge_stp_helper
          request_key_helper
        ];
        inherit rpiModel;
      };

      # https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/kernel/linux-rpi.nix
      # overriding other override like this doesn't work
      # linux_rpi5 = self.linux_rpi4.override {
      #   rpiVersion = 5;
      #   argsOverride.defconfig = "bcm2712_defconfig";
      # };
      # linux_rpi5_v6_6_28 = self.linux_rpi4_v6_6_28.override {
      #   rpiVersion = 5;
      #   argsOverride = (linux_v6_6_28_argsOverride super) // {
      #     defconfig = "bcm2712_defconfig";
      #   };
      # };
    };
  in map linuxVersionForModel models;

in self: super: super.lib.mergeAttrsList (
  builtins.concatLists [
    (mkLinuxFor super "6_6_74_cfg" [ "5" ])
    (mkLinuxFor super "6_6_74" [ "02" "4" "5" ])
    (mkLinuxFor super "6_6_51" [ "02" "4" "5" ])
    (mkLinuxFor super "6_6_31" [ "4" "5" ])
    (mkLinuxFor super "6_6_28" [ "4" "5" ])
    (mkLinuxFor super "6_1_73" [ "4" "5" ])
    (mkLinuxFor super "6_1_63" [ "4" "5" ])
  ])
