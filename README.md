# nixos-raspberrypi

Unopinionated Nix flake for infrastructure, vendor packages, kernel, and some optimized third-party packages for [NixOS](https://nixos.org/) running on Raspberry Pi devices.

It will let you deploy [NixOS](https://nixos.org/) fully declaratively in one step with tools like [nixos-anywhere](https://github.com/nix-community/nixos-anywhere/).

## What does it do

Provisions and manages Raspberry Pi firmware partition `/boot/firmware`. Partition is being provisioned on nixos generation switch (integrated with bootloader activation scripts, as opposed to oneshot systemd services, for example), enabling to use deployment tools like `nixos-anywhere` without any interactive intervention.

Supported boot methods: `kernelboot`, `uboot`. Also mostly-working `uefi` in a separate branch.

## How to use

This flake can be consumed in a number of ways:

### Add flake input
```flake.nix
inputs = {
  nixos-raspberrypi = {
    url = "github:nvmd/nixos-raspberrypi";
    inputs = {
      # optionally follow your own `nixpkgs` inputs
      # this may make binary cache unavailable!
      # this flake may follow different channel, check `flake.nix` to avoid unexpected rebuilds!
      nixpkgs.follows = "nixpkgs-unstable";
    };
  };
};
```

### Optional: Use binary cache

Pre-built packages are provided for `nixpkgs` version locked with `flake.lock`.
Depending on the circumstances, it may be either stable `nixpkgs` or `nixpkgs-unstable`. Check `inputs.nixpkgs` in `flake.nix` if it's important for you.

Can be enabled globally to the NixOS configuration:
```nix
imports = with nixos-raspberrypi.nixosModules; [
  trusted-nix-caches
];
```

Or for the flake only:
```flake.nix
nixConfig = {
  extra-substituters = [
    "https://nixos-raspberrypi.cachix.org"
  ];
  extra-trusted-public-keys = [
    "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
  ];
};
```

### Import modules corresponding to your hardware

```nix
imports = with nixos-raspberrypi.nixosModules; [
  # choose one of the following base board support modules
  raspberry-pi-4.base
  raspberry-pi-5.base

  # RPi4:
  # import this if you have the display, on rpi4 this is the only display configuration option
  raspberry-pi-4.display-vc4
  # Fan control for ArgonOne V2 case
  # raspberry-pi-4.case-argonone # work-in-progress

  # RPi5-specific, one of them for "PrimaryGPU" configuration:
  raspberry-pi-5.display-vc4  # "regular" display connected
  raspberry-pi-5.display-rp1  # for RP1-connected (DPI/composite/MIPI DSI) display

  usb-gadget-ethernet # Configures USB Gadget/Ethernet - Ethernet emulation over USB
];
```

See `flake.nix`, `nixosModules` for a full list of configuration modules for your hardware.

### Import overlays you want

By default, modules use packages available in `pkgs`, i.e. they don't internally apply any of the overlays provided by this flake to avoid potential conflicts with what you may want to achieve.

If you don't have any special needs, you may import helper modules to apply overlays for you
```nix
imports = [
  # Required: Bootloaders, linux kernel, firmware, raspberry's utils
  # additionally, `nixpkgs.rpi` with _all_ overlays applied (see below)
  nixos-raspberrypi.lib.inject-overlays

  # Adds raspberry overlay on top of `nixpkgs`, so that you may access all optimized packages via `pkgs.rpi`
  nixos-raspberrypi.nixosModules.nixpkgs-rpi

  # Optional: Applies overlays with optimized packages to the global scope, 
  # including ffmpeg_{4,6,7}, kodi, libcamera, SDL2, vlc
  # Use with caution – this may cause lots of rebuilds (even though many 
  #  packages should be available in a binary cache above)
  nixos-raspberrypi.lib.inject-overlays-global
];
```

For more fine-grained control and full overlay list see `overlays` in `flake.nix`, and overlay helpers (mentined above) in `lib`.


#### Alternative ways to get individual packages

An alternative ways to consume individual packages without overlays are:

* to get it directly from the flake, it will based on stable `nixpkgs` _without_ any of other optimisations transitively applied (i.e. only this particular package is optimised):

```nix
  environment.systemPackages = [
    nixos-raspberrypi.packages.aarch64-linux.vlc
  ];
```

* to get it from `nixos-raspberrypi.legacyPackages.<system>`. Here all overlays are applied.


### Configure

Sane default configuration is provided by the base module for a corresponding Raspberry board, but further configuration is, of course, possible:

Configuration options for the bootloader are in `boot.loader.raspberryPi` (defined in `modules/system/boot/loader/raspberrypi/default.nix`).

Raspberry's `config.txt` can be configured with `hardware.raspberry-pi.config` options, see `modules/configtxt.nix` as an example (this is the default configuration as provided by RaspberryPi OS, but translated to nix format).

### Configuration examples

There's a configuration example `nixosConfigurations.rpi02-installer` in `flake.nix`, which also doubles as an installation SD card image for Raspberry Pi Zero2.
SD image can be built with:
```
$ nix build .#installerImages.rpi02
```
Replace `# YOUR SSH PUB KEY HERE #` with your SSH public key to be able to access the system via USB Ethernet gadget functinality right away.
`.#nixosConfigurations.rpi02-installer.config.system.build.toplevel` is also included in the binary cache.


### Deploy

for example, with `nixos-anywhere` to the system running installer image (will use [disko](https://github.com/nix-community/disko/) to set the disks up):
```shell
$ nixos-anywhere --flake .#<system> root@<hostname>"
```

or, to an already running system:
```shell
$ nixos-rebuild switch --flake .#<system> --target-host root@<hostname>
```


## Design goals

This is basically [`boot.loader.raspberryPi` options](https://search.nixos.org/options?channel=unstable&show=boot.loader.raspberryPi), which are deprecated in nixpkgs, but updated and improved upon.

Design objectives:
* individually consumable modules and overlays for specific functions
* reuse of the existing nixos/nixpkgs infrastructure and idiomatic approaches to the maximum extent possible
* integration with the existing nixos system activation


## Historical background

This project grew naturally out of the need to configure and extend rather great [tstat's raspberry pi support repository](https://github.com/tstat/raspberry-pi-nix), which we used for some time.

Unfortunately it was virtually possible to work with without reengineering the whole thing, so this Flake was born. Inability to use it non-interactively with `nixos-anywhere` was the biggest concern.

We found [`boot.loader.raspberryPi` options](https://search.nixos.org/options?channel=unstable&show=boot.loader.raspberryPi) to be much more idiomatic, easier to extend, and maintain.

This flake strives to keep and improve those properties by keeping it as unopinionated as possible and modular (see [above](#design-goals))

We're still using some ot the modules provided by an adapted fork of tstat/raspberry-pi-nix, namely `config.txt` generation module.
