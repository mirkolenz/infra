<!-- markdownlint-disable MD033 -->

# Nix Setup

This repo contains a custom wrapper to build NixOS/nix-darwin/home-manager:

```shell
nix run github:mirkolenz/infra -- --wrapper-help
```

## Repository Structure

This flake follows the **dendritic pattern**: every `.nix` file under `modules/` is auto-loaded by `import-tree` (see `flake.nix`) and contributes to a `flake.modules.<class>.<bucket>` declaration, so the directory a file lives in is purely organizational.
Feature modules are grouped by the **config-path namespace** they write, mirroring the option tree (and the `options/` layout), so anything is found where it sits in the configuration.
A module is one cohesive feature filed under one directory, the namespace of its primary subject, while keeping all of its config inline, so a feature like `ssh` or `nix` is configured end-to-end across home-manager and nixos/darwin in a single file.

## NixOS Computers

### Manual Terminal Setup

- <https://www.adaltas.com/en/2022/02/08/nixos-installation/>
- <https://wiki.nixos.org/wiki/NixOS_Installation_Guide>
- <https://gist.github.com/Vincibean/baf1b76ca5147449a1a479b5fcc9a222>

#### Partitioning

```shell
parted -l # find device name
wipefs -a /dev/sda
parted /dev/sda
mklabel gpt
mkpart boot fat32 0% 512MiB
set 1 esp on
unit GiB print free
# determine the swap size by substractting the amount of your ram from the free size
# for instance, free size here is 238GiB and the ram of the system is 8GiB
mkpart root ext4 512MiB 230GiB
mkpart swap linux-swap 230GiB 100%
```

#### Formatting

```shell
mkfs.fat -F 32 -n boot /dev/sda1
mkfs.ext4 -L root /dev/sda2
mkswap -L swap /dev/sda3
```

#### Mounting

```shell
mount /dev/disk/by-label/root /mnt
swapon /dev/disk/by-label/swap
mkdir -p /mnt/boot
mount /dev/disk/by-label/boot /mnt/boot
# generate hardware config with filesystems
nixos-generate-config --root /mnt
```

The rest is identical to the disko-based setup after `nixos-generate-config`.

### Disko Terminal Setup

- <https://github.com/nix-community/disko/blob/master/docs/quickstart.md>
- <https://github.com/nix-community/disko/blob/master/docs/reference.md>

```shell
# find device name and update this flake accordingly
ls -l /dev/disk/by-id
# format the disk
nix run github:mirkolenz/infra#disko -- MACHINE_NAME --mode destroy,format,mount
# generate hardware config and verify /mnt/etc/nixos/hardware-configuration.nix is in sync with the flake
nixos-generate-config --no-filesystems --root /mnt
# set up user passwords
bash -c 'umask 022 && mkdir -p /mnt/etc/nixos/secrets'
bash -c 'umask 077 && mkpasswd -m yescrypt > /mnt/etc/nixos/secrets/USER.passwd'
# install the system
nix run github:mirkolenz/infra#nixos-install -- MACHINE_NAME
```

### Troubleshooting

- A warning about `/boot` being world-readable is not an issue, [the permissions are correctly set after a reboot](https://discourse.nixos.org/t/nixos-install-with-custom-flake-results-in-boot-being-world-accessible/34555).
- If you get an error like `too many open files` during `nixos-install`, try one of the following options:
  - Execute `ulimit -n 65535` before installing to increase the number of open files for the current shell session
  - Use `--max-jobs 2` to limit the number of parallel jobs (could also try with 1 max job)
- If you get an error like `Getting status of /nix/store/...: No such file or directory`, try the following:
  ```shell
  nix-store --verify --check-contents --repair
  ```

### Tailscale

- Create auth key: <https://login.tailscale.com/admin/settings/keys>
- SSH into the machine
- Save the auth key to `./tsauth.txt`
- Run `sudo tailscale up --auth-key file:tsauth.txt`
- Run `tailscale status` to verify the connection
- Remove the auth key file: `rm ./tsauth.txt`
- Approve exit-node/routes: <https://login.tailscale.com/admin/machines>

## Mac Computers

### Installation

1. Install Apple Developer Tools: `xcode-select --install`
2. [Install Homebrew](https://github.com/Homebrew/brew/releases/latest)
3. [Install Nix](https://docs.determinate.systems)
4. Sign into the App Store
5. Enable Full Disk Access for terminal application

```shell
sudo nix run github:mirkolenz/infra
sudo reboot
# Add ssh key to keychain
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

### Sync Configs to a Mac without Nix

For Macs that should not have Nix installed, the `mirkos-macbook-rsync` package copies a curated set of configuration files (Ghostty, SSH client, Homebrew bundle) from this flake to the remote machine via rsync over SSH.
The list of files and the `brew bundle` invocation are derived directly from `darwinConfigurations.mirkos-macbook`, so they stay in sync with the nix-darwin configuration.

Before running, make sure SSH key-based login to the remote works.

```shell
ssh-copy-id -i "$HOME/.ssh/id_ed25519.pub" "USER@MACHINE_NAME"
```

Then sync the configs and apply any manual steps.

```shell
nix run .#mirkos-macbook-rsync -- USER@HOST
```

To extend the script with additional files, add an entry to the `entries` list in `mirkos-macbook-rsync.nix`.

### Uninstallation

```shell
chsh -s /bin/zsh
# if nix is not in PATH, use this: /nix/var/nix/profiles/default/bin/nix
sudo nix run github:mirkolenz/infra#darwin-uninstaller
sudo /nix/nix-installer uninstall
```

### Applications and Settings

<details>
<summary>Shell</summary>

- Copy `$HOME/.local/share/fish/fish_history`

</details>

<details>
<summary>System Preferences</summary>

- `General > About`: Set name
- `Wallpaper`: Solid color (black)
- `Appearance > Allow wallpaper tinting in windows`: Off
- `Keyboard > Keyboard Shortcuts > Modifier Keys`: Caps Lock -> Option
- `Keyboard > Keyboard Shortcuts > App Shortcuts`: Disable all
- `Keyboard > Keyboard Shortcuts > Spotlight`: Disable all

</details>

<details>
<summary>Raycast</summary>

- `Settings > Advanced > Import/Export` (also set up new schedule)
- `Launch > Manage Fallback Command`: Add Kagi

</details>

<details>
<summary>Visual Studio Code</summary>

- `Settings > Backup and Sync Setting > GitHub`

</details>

<details>
<summary>Zotero</summary>

- Install [Better BibTeX](https://github.com/retorquere/zotero-better-bibtex/releases)
- Install [Open PDF](https://github.com/retorquere/zotero-open-pdf/releases)
- `Settings > General > Customize Filename Format > {{ creators max="1" case="hyphen" }}-{{ year }}-{{ title truncate="50" case="hyphen" }}`
- `Settings General > Reader > Tabs > Creator - Title - Year`
- `Settings > Export > Item Format > Better BibTeX Citation Key Quick Copy`
- `Settings > Export > Note Format > Markdown + Rich Text`
- `Settings > Better BibTeX > Citation Key Format > auth.capitalize + year + shorttitle(3,3)`
- `Settings > Better BibTeX > Citation Key Format > Automatic Export > Delay > 10 seconds`
- `Settings > Better BibTeX > Fields > Omit > file, keywords`

</details>

<details>
<summary>Default Folder X</summary>

- `Settings > Options > Sync settings via iCloud`

</details>

<details>
<summary>Arq Backup</summary>

Additional wildcard exclude rules:

```txt
.cache
.devenv
.direnv
.orbstack
.venv
__pycache__
node_modules
*/OrbStack
*/Library/CloudStorage
*/Library/Application Support/
```

</details>

## Home-Manger Standalone

_Note:_ Reconnect via SSH after installing nix.

```shell
ssh-copy-id -i "$HOME/.ssh/id_ed25519.pub" "USER@MACHINE_NAME"
sudo /nix/var/nix/profiles/default/bin/nix upgrade-nix
nix run github:mirkolenz/infra
sudo usermod -s $(which fish) "$USER"
```

## Utilities and Snippets

### Nix Access Tokens

To avoid rate limiting, add a [GitHub access token](https://nix.dev/manual/nix/stable/command-ref/conf-file.html#conf-access-tokens).
Add the following to `/etc/nix/nix.secrets.conf`:

```ini
access-tokens = github.com=github_pat_XXX
```

### Image Building

If building for another architecture on NixOS:
[Enable cross compiling](https://github.com/nix-community/nixos-generators#cross-compiling)

```shell
# for iso installer disc
nix build github:mirkolenz/infra#.legacyPackages.x86_64-linux.installer-default.iso-installer
# for raspberry pi sd card
nix build github:mirkolenz/infra#.legacyPackages.aarch64-linux.installer-raspi.sd-card
# for apple t2
nix build github:mirkolenz/infra#.legacyPackages.x86_64-linux.installer-apple-t2.iso-installer
```

### Update Raspberry Pi

<https://nix.dev/tutorials/installing-nixos-on-a-raspberry-pi#updating-firmware>

```shell
sudo mount /dev/disk/by-label/FIRMWARE /mnt
sudo env BOOTFS=/mnt FIRMWARE_RELEASE_STATUS=default rpi-eeprom-update -d -a
sudo reboot
```

### Use MakeMKV

```shell
# otherwise the optical drive is not found: https://discourse.nixos.org/t/makemkv-cant-find-my-usb-blu-ray-drive/23714
sudo modprobe sg
# if that does not work, try again with sudo
nix run github:mirkolenz/infra#makemkv
```

### Investigate ID Mappings

```shell
sudo podman run --rm --subuidname=$USER ubuntu cat /proc/self/uid_map
```

### Password Hashing

```shell
sudo bash -c 'umask 022 && mkdir -p /etc/nixos/secrets'
sudo bash -c 'umask 077 && mkpasswd -m yescrypt > /etc/nixos/secrets/USER.passwd'
```

### Zellij Web Tokens

```shell
zellij web --create-token
```

### SSH Key Generation

```shell
ssh-keygen -t ed25519 -a 128 -C "USER@HOST" -f ~/.ssh/id_ed25519
```
