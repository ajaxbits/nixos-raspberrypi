{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.loader.raspberryPi;
  isAarch64 = pkgs.stdenv.hostPlatform.isAarch64;

  ubootBinName = if isAarch64 then "u-boot-rpi-arm64.bin" else "u-boot-rpi.bin";


  # Builders used to write during system activation
  firmwareBuilder = import ./firmware-builder.nix {
    inherit pkgs configTxt;
    firmware = cfg.firmwarePackage;
  };
  rpibootBuilder = import ./raspberrypi-builder.nix {
    inherit pkgs;
    firmwareBuilder = firmwarePopulateCmd.firmware;
  };
  ubootBuilder = import ./uboot-builder.nix {
    inherit pkgs ubootBinName;
    inherit (cfg) ubootPackage;
    firmwareBuilder = firmwarePopulateCmd.firmware;
    extlinuxConfBuilder = config.boot.loader.generic-extlinux-compatible.populateCmd;
  };
  uefiBuilder = pkgs.substituteAll {
    src = ./uefi-builder.sh;
    isExecutable = true;
    inherit (pkgs) bash;
    path = [pkgs.coreutils pkgs.gnused pkgs.gnugrep];

    uefi = uefiPackage;
    uefiBinName = "RPI_EFI.fd";
    inherit configTxt;
  };
  # Builders exposed via populateCmd, which run on the build architecture
  populateFirmwareBuilder = import  ./firmware-builder.nix {
    inherit configTxt;
    pkgs = pkgs.buildPackages;
    firmware = cfg.firmwarePackage;
  };
  populateRpibootBuilder = import ./raspberrypi-builder.nix {
    pkgs = pkgs.buildPackages;
    firmwareBuilder = firmwarePopulateCmd.firmware;
  };
  populateUbootBuilder = import ./uboot-builder.nix {
    inherit ubootBinName;
    pkgs = pkgs.buildPackages;
    ubootPackage = cfg.ubootPackage;
    firmwareBuilder = firmwarePopulateCmd.firmware;
    extlinuxConfBuilder = config.boot.loader.generic-extlinux-compatible.populateCmd;
  };


  firmwareBuilderArgs = lib.optionalString (!cfg.useGenerationDeviceTree) " -r";

  builder = {
    firmware = "${firmwareBuilder} -d ${cfg.firmwarePath} ${firmwareBuilderArgs} -c";
    uboot = "${ubootBuilder} -f ${cfg.firmwarePath} -d ${cfg.bootPath} -c";
    uefi = "${uefiBuilder} -f ${cfg.firmwarePath} -d ${cfg.bootPath} -c";
    rpiboot = "${rpibootBuilder} -d ${cfg.firmwarePath} -c";
  };
  firmwarePopulateCmd = {
    firmware = "${populateFirmwareBuilder} ${firmwareBuilderArgs}";
    rpiboot = "${populateRpibootBuilder}";
    uboot = "${populateUbootBuilder}";
    # uefi = "${populateUefiBuilder}";
  };

  configTxt = config.hardware.raspberry-pi.config-output;

in

{
  disabledModules = [ "system/boot/loader/raspberrypi/raspberrypi.nix" ];


  options = {

    boot.loader.raspberryPi = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Whether to manage boot firmware, device trees and bootloader
          with this module
        '';
      };

      firmwarePackage = mkPackageOption pkgs "raspberrypifw" { };

      bootPath = mkOption {
        default = "/boot";
        type = types.str;
        description = ''
          Target path for:
          - uboot: extlinux configuration - (extlinux/extlinux.conf, initrd, 
              kernel Image)
          - uefi: systemd configuration
          This partition must have set for the bootloader to work:
          - uboot: either GPT Legacy BIOS Bootable partition attribute, or 
                   MBR bootable flag
          - uefi: GPT partition type EF00 (EFI System Partition)
        '';
      };

      firmwarePath = mkOption {
        default = "/boot/firmware";
        type = types.str;
        description = ''
          Target path for system firmware and:
          - rpi: system generations, `<firmwarePath>/old` will hold
            files from old generations.
          - uboot: uboot binary
        '';
      };

      useGenerationDeviceTree = mkOption {
        default = false;  # generic-extlinux-compatible defaults to `true`
        type = types.bool;
        description = ''
          Whether to use device tree supplied from the generation's kernel
          or from the vendor's firmware package (usually `pkgs.raspberrypifw`).

          When enabled, the device tree binaries will be copied to
          `firmwarePath` from the generation's kernel.

          This affects `rpiboot` and `uboot` bootloaders.

          Note that this affects all generations, regardless of the
          setting value used in their configurations.
        '';
      };

      firmwarePopulateCmd = mkOption {
        type = types.str;
        readOnly = true;
        description = ''
          Contains the builder command used to populate an image with both
          selected bootloader and firmware.

          Honors all relevant module options except the
          `-c <path-to-default-configuration>`
          `-d <target-dir>` arguments, which can be specified
          by the caller of firmwarePopulateCmd.

          Useful to have for sdImage.populateFirmwareCommands
        '';
      };

      bootloader = mkOption {
        default = if cfg.variant == "5" then "rpiboot" else "uboot";
        type = types.enum [ "rpiboot" "uboot" ];
        description = ''
          Bootloader to use:
          - `"uboot"`: U-Boot
          - `"rpiboot"`: The linux kernel is installed directly into the
            firmware directory as expected by the Raspberry Pi boot
            process.
            This can be useful for newer hardware that doesn't yet have
            uboot compatibility or less common setups, like booting a
            cm4 with an nvme drive.
        '';
      };

      variant = mkOption {
        type = types.enum [ "0" "0_2" "1" "2" "3" "4" "5" ];
        description = "";
      };

      ubootPackage = mkOption {
        default = {
          "0" = {
            armhf = pkgs.ubootRaspberryPiZero;
          };
          "0_2" = {
            aarch64 = pkgs.ubootRaspberryPi_64bit;
          };
          "1" = {
            armhf = pkgs.ubootRaspberryPi;
          };
          "2" = {
            armhf = pkgs.ubootRaspberryPi2;
          };
          "3" = {
            armhf = pkgs.ubootRaspberryPi3_32bit;
            aarch64 = pkgs.ubootRaspberryPi_64bit;
          };
          "4" = {
            aarch64 = pkgs.ubootRaspberryPi_64bit;
          };
          "5" = {
            aarch64 = pkgs.ubootRaspberryPi_64bit;
          };
        }.${cfg.variant}.${if isAarch64 then "aarch64" else "armhf"};
      };

    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      assertions = let supportAarch64 = [ "0_2" "3" "4" "5" ];
      in singleton {
        assertion = !pkgs.stdenv.hostPlatform.isAarch64
                    || builtins.elem cfg.variant supportAarch64;
        message = ''
          Only Raspberry Pi versions
          ${builtins.concatStringsSep ", " supportAarch64} support aarch64.
        '';
      };
      system.build.installFirmware = builder."firmware";
      boot.loader.raspberryPi.firmwarePopulateCmd = firmwarePopulateCmd."${cfg.bootloader}";
    })

    (mkIf (cfg.enable && (cfg.bootloader == "rpiboot")) {
      hardware.raspberry-pi.config = {
        all = {
          options = {
            kernel = {
              enable = true;
              value = "kernel.img";
            };
          };
        };
      };
      hardware.raspberry-pi.extra-config = ''
        [all]
        initramfs initrd followkernel
      '';

      boot.loader.grub.enable = false;

      system = {
        build.installBootLoader = builder."rpiboot";
        boot.loader.id = "raspberrypi";
        boot.loader.kernelFile = pkgs.stdenv.hostPlatform.linux-kernel.target;
      };
    })

    (mkIf (cfg.enable && (cfg.bootloader == "uboot")) {
      hardware.raspberry-pi.config = {
        all = {
          options = {
            kernel = {
              enable = true;
              value = ubootBinName;
            };
          };
        };
      };

      # Enable to manage extlinux' options with its builder/populateCmd ...
      boot.loader.generic-extlinux-compatible = {
        enable = true;
        # if false, don't add FDTDIR to the extlinux conf file to use the device tree
        # provided by firmware. (we usually want this to be false)
        useGenerationDeviceTree = cfg.useGenerationDeviceTree;
      };

      boot.loader.grub.enable = false;

      # ... These are also set by generic-extlinux-compatible, but we need to
      # override them here to be able to setup config.txt,firmware, etc
      # before setting up extlinux
      # `lib.mkOverride 60` to override the default, while still allowing
      # consuming modules to override with mkForce
      system = {
        build.installBootLoader = lib.mkOverride 60 (builder."uboot");
        boot.loader.id = lib.mkOverride 60 ("uboot+extlinux");
      };
    })

    (mkIf (cfg.enable && (cfg.bootloader == "uefi")) {
      hardware.raspberry-pi.config = {
        all = {
          options = {
            armstub = {
              enable = true;
              value = "RPI_EFI.fd";
            };
            device_tree_address = {
              enable = true;
              value = "0x1f0000";
            };
            device_tree_end = {
              enable = true;
              value = ({
                "4" = "0x200000";
                "5" = "0x210000";
              }.${cfg.variant});
            };
            framebuffer_depth = {
              # Force 32 bpp framebuffer allocation.
              enable = lib.mkDefault (cfg.variant == "5");
              value = 32;
            };
            disable_overscan = {
              # Disable compensation for displays with overscan.
              enable = true;
              value = 1;
            };
            disable_commandline_tags = {
              enable = lib.mkDefault (cfg.variant == "4");
              value = 1;
            };
            enable_uart = {
              enable = lib.mkDefault (cfg.variant == "4");
              value = true;
            };
            uart_2ndstage = {
              enable = lib.mkDefault (cfg.variant == "4");
              value = 1;
            };
            enable_gic = {
              enable = lib.mkDefault (cfg.variant == "4");
              value = 1;
            };
          };
          dt-overlays = {
            miniuart-bt = {
              enable = lib.mkDefault (cfg.variant == "4");
              params = { };
            };
            upstream-pi4 = {
              enable = lib.mkDefault (cfg.variant == "4");
              params = { };
            };
          };
        };
      };

      boot.loader.efi.canTouchEfiVariables = true;
      boot.loader.systemd-boot = {
        enable = true;
        #   default_cfg=$(cat /boot/loader/loader.conf | grep default | awk '{print $2}')
        #   init_value=$(cat /boot/loader/entries/$default_cfg | grep init= | awk '{print $2}')
        #   sed -i "s|@INIT@|$init_value|g" /boot/custom/config_with_placeholder.conf
        extraInstallCommands = ''
          ${uefiBuilder}
        '';
      };

      # system = {
      #   build.installBootLoader = lib.mkOverride 60 (builder."uefi-rpi");
      #   boot.loader.id = lib.mkOverride 60 ("uefi-rpi");
      # };
    })

  ];
}
