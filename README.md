# ![image](https://github.com/user-attachments/assets/128c8a61-2dcc-45a5-a972-6335c6c9a7fd) Linux BSP Case Folding Workaround (lbspcfw)

Linux BSP Case Folding Workaround is a Linux bash script designed to resolve client-side compatibility with maps (BSP) with case folding issues with custom content in Valve Source 1 engine games on Linux, such as Half-Life 2 Deathmatch, Counter-Strike: Source, Team Fortress 2, and many others. It addresses missing textures, models, and sounds due to case sensitivity mismatches by extracting and syncing assets to the game folder, from which they are then parsed properly by the game.<br/>
- No modification to any map or game files and is completely safe to use with secure servers (zero risk of VAC ban).
- Game stability restored, reducing map-related crashes since the assets will once again be available.

#### 🖼️ Before/After
![image](https://github.com/user-attachments/assets/e8b1c04d-778d-42bf-83f6-a68c1d446c2d)
![image](https://github.com/user-attachments/assets/9acf4dcb-92d4-4e85-af89-8c2859777e0c)

## ℹ️ Purpose
BSP map files reference assets (e.g., Materials/Walls/brick01.vtf) case-insensitively, which conflicts with Linux case-sensitive filesystem (e.g., materials/walls/brick01.vtf) since the February 2025 update. This script automates bulk asset extraction, merge, and placement to ensure proper map operation.

## 👨‍💻 Functionality
- Automatically updates to the latest LBSPCFW and [VPKEdit](https://github.com/craftablescience/VPKEdit/releases) (for asset extraction)
- Auto-detection of compatible Steam Games (Flatpack & Snap also supported)
- Extracts custom map assets with vpkeditcli and merges them together with rsync
- Uses [GNU Parallel](https://github.com/gitGNU/gnu_parallel) for processing all map data, drastically reducing workload time
- Syncronization can be set to your game folder (auto-detect), or `fix` folder (manually copy contents to game `download` folder)
- Optionally skip previously processed maps per game using hash fingerprinting for accurate checking (new, changed, same, etc)
- Automatic configuration preset generation to streamline reprocessing of new/existing map files on a per-game basis

## 🚀 Usage
### Prerequisites
- Linux OS with bash
- Dependencies: `curl inotifywait notify-send parallel rsync unzip`
- Missing dependencies can be optionally be installed automatically by running the script

Manual
- To manually install dependencies, run the following command specific to your distribution:

Ubuntu/Debian-based (apt)
```
sudo apt update && sudo apt install curl inotify-tools libnotify-bin parallel rsync unzip -y
```
Arch Linux-based (pacman)
```
sudo pacman -Syy --noconfirm curl inotify-tools libnotify parallel rsync unzip
```
Fedora-based (dnf)
```
sudo dnf makecache && sudo dnf install curl inotify-tools libnotify parallel rsync unzip -y
```
Gentoo-based (portage)
```
sudo emerge --sync && sudo emerge -qN net-misc/curl sys-fs/inotify-tools x11-libs/libnotify sys-process/parallel net-misc/rsync app-arch/unzip
```

### Installation
1. Clone:
   ```
   git clone https://github.com/scorpius2k1/linux-bsp-casefolding-workaround.git
   ```
2. Change to local repo folder
   ```
   cd linux-bsp-casefolding-workaround
   ```
3. Set permissions:
   ```
   chmod +x lbspcfw.sh
   ```
Alternatively, clone & run with one command:
```
git clone https://github.com/scorpius2k1/linux-bsp-casefolding-workaround.git && cd linux-bsp-casefolding-workaround && chmod +x lbspcfw.sh && ./lbspcfw.sh
```

### Execution
- Auto-detect:
  - Run `./lbspcfw.sh` (select **Y** to auto detect, choose game)
  - If you do not see your game in the list, please proceed with the manual method
  - Maps already in your game folder `download/maps` are used, negating the need to copy map files
- Manual:
  - Create a `bsp` folder in the same folder as the script
  - Copy desired map files (bsp) into the `bsp` folder
  - Run `./lbspcfw.sh` (select **N** to auto detect)
  - Once the script has finished, move the contents of `fix` into game `download` folder<br/>(e.g., ../steamapps/common/Half-Life 2 Deathmatch/hl2mp/download/)
- Presets:
  - Configuration presets are automatically generated after first processing, on a per-game basis
  - To use a preset, run the script normally and answer **Y** to the `Use configuration preset? [Y/n]` prompt and choose the desired game to reprocess
  - Alternatively, the `--config` parameter can also be passed as a command line argument `./lbspcfw.sh --config` to skip directly to the preset menu

#### ** Map files are **not altered** in any way, data is only extracted from them **
![Screenshot from 2025-03-08 10-50-46](https://github.com/user-attachments/assets/80e46bdb-a529-4859-9e6d-d646daace166)

## 🖥️ Automation
- There are three options available: _script runtime_, _systemd service_, and _steam_ which can be ran simultaneously in the background to automatically process new maps for multiple games.

1. **Script**<br/>
   Use the `--monitor` argument when running the script. After processing, the monitor will automatically be started and remain running in the terminal until stopped<br/>
   ![image](https://github.com/user-attachments/assets/188e88a8-7eaf-47d3-a8ee-d94af5dc7aff)

2. **Service**<br/>
   To create systemd services that will automatically process maps in the background, use the `--service` argument when running the script. Services are created from existing game presets, but can also be created if none are available during initial game processing. Service status can also be checked via systemd status command for the desired game, eg. `systemd status --user lbspcfw-hl2mp.service`. Services are managed the same way as any other systemd service, please visit the official [systemd website](https://systemd.io/) for specific documentation. All script systemd service monitors are placed in `$HOME/.config/systemd/user` with the lbspcfw prefix.<br/>
   ![image](https://github.com/user-attachments/assets/eaef2290-4208-4461-adc8-519672cb4b43)

3. **Steam**<br/>
   Steam background monitoring can be enabled on game launch by adding `/path/to/lbspcfw.sh %command%` in your desired games runtime command option. Before adding to Steam, the script should be ran at least once to ensure all dependencies are available. _Steam installs using snap/flatpak may not work with this option!_<br/>
   ![image](https://github.com/user-attachments/assets/c3464989-5163-4f02-8fa1-7dd48dc4527f)


When using automation, it is possible that some maps may be loaded by the game before the assets can be fully extracted and synchronized, even with instantaneous script detection and implemented processing delay for new maps. If this happens, missing textures may still be present; try reconnecting to the server, restarting the game, or loading the map locally. Servers that are enforcing `sv_pure` can [also be a factor](https://github.com/scorpius2k1/linux-bsp-casefolding-workaround/issues/7) since this typically does not allow for custom assets outside of the loaded map. In this case, a fix issued by Valve for affected games is the only option.

## ⚠️ Backup Warning
To work properly, all assets (materials, models, sound) extracted are **required** to be inside the game download folder (alternatively, they can be placed in the game root folder). Placing custom assets into the `custom` folder does not work since it seems to suffer the same case folding issue. This is due to the functionality of the game itself, _not_ the script. If you require any existing custom content to be retained, please back up your existing materials/models/sound folders **_prior_** to running this script.

## 🚩 Known Issues
Multiple maps that use the same texture/model naming scheme but different versions can potentially [conflict with eachother](7), causing them not to render properly. While rare, this is difficult to address directly since the way Valve's Source1 engine processes external data cumulatively (no per-map option), making it implausible to address via a workaround such as this script.

## 🗑 Removal
- Navigate to your game `download` folder and remove `materials` `models` `sound` folders. If you retained any backups of these folders, be sure to restore them there afterwards. Once done, restart the game.

## 👥 Support
- A ticket for this issue is open on Valve's official Github, please [follow there](https://github.com/ValveSoftware/Source-1-Games/issues/6868) for updated information.
- If you find this useful and it works well for you, please ⭐ this repository and share with others in the community.
- If you would like to support my work and [servers](https://stats.scorpex.org/) I run in the community, consider [buying a coffee](https://help.scorpex.org/?s=git) ☕
  
[Back to top](#top)
