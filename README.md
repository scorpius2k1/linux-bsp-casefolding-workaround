# Linux BSP Case Folding Workaround (lbspcfw)

#### 🖼️ Before/After
![image](https://github.com/user-attachments/assets/e8b1c04d-778d-42bf-83f6-a68c1d446c2d)
![image](https://github.com/user-attachments/assets/9acf4dcb-92d4-4e85-af89-8c2859777e0c)


## 📜 Overview
The Linux BSP Case Folding Workaround is a bash script designed to resolve compatibility issues with BSP (Binary Space Partition) map files in Valve Source1 engine games on Linux, such as Half-Life 2 Deathmatch, Counter-Strike: Source, Team Fortress 2, and many others. It addresses missing textures, models, and sounds due to case sensitivity mismatches by extracting and syncing assets to the game folder from which they are then parsed properly by the game. This also helps game stability by reducing map crashes since the assets will once again be available.<br/><br/>
**Multiplayer servers with sv_pure disabled also work with this since there are no modifications made to the bsp files themselves.**

## ℹ️ Purpose
BSP map files reference assets (e.g., Materials/Walls/brick01.vtf) case-insensitively, which conflicts with Linux case-sensitive filesystem (e.g., materials/walls/brick01.vtf) since the February 2025 update. This script automates bulk asset extraction, merge, and placement to ensure proper map operation.

## 👨‍💻 Functionality
- Automatically downloads the latest [vpkeditcli](https://github.com/craftablescience/VPKEdit/releases) for asset extraction.
- Auto-detection of compatible Steam Games (Flatpack & Snap also supported)
- Extracts custom map assets with vpkeditcli and merges them together with rsync
- Syncronization can be set to your game folder (auto-detect), or `fix` folder (manually copy contents to game `download` folder)

## 🚀 Usage
### Prerequisites
- Linux OS with bash.
- Dependencies: **curl**, **unzip**, **rsync** (install via your distribution package manager, if needed).

### Installation
1. Clone:
   ```
   git clone https://github.com/scorpius2k1/linux-bsp-casefolding-workaround.git
   ```
2. Set permissions:
   ```
   chmod +x lbspcfw.sh
   ```

### Execution
- Auto-detect: ./lbspcfw.sh (select **Y** for autodetect, choose game).
  - If you do not see your game in the list, please proceed with the manual method
  - Maps already in your game folder `download/maps` are used, negating the need to copy map files
- Manual:
  - Create a `bsp` folder in the same folder as the script
  - Copy desired map files (bsp) into the `bsp` folder
  - Run `./lbspcfw.sh` (select **N** to auto detect)
  - Once the script has finished, move the contents of `fix` into game `download` folder<br/>(e.g., ../steamapps/common/Half-Life 2 Deathmatch/hl2mp/download/).

#### ** Map files are **not altered** in any way, data is only extracted from them **
![image](https://github.com/user-attachments/assets/95ad61e1-d294-4c41-815c-ddbdf8546789)

## ⚠️ Backup Warning
To work properly, all assets (materials, models, sound) extracted are **required** to be inside the game download folder (alternatively, they can be placed in the game root folder). Placing custom assets into the `custom` folder does not work since it seems to suffer the same case folding issue. This is due to the functionality of the game itself, _not_ the script. If you require any existing custom content to be retained, please back up your existing materials/models/sound folders **_prior_** to running this script.

## 🗑 Removal
- Navigate to your game `download` folder and remove `materials` `models` `sound` folders. If you retained any backups of these folders, be sure to restore them there afterwards. Once done, restart the game.

## 👥 Support
- A ticket for this issue is open on Valve's official Github, please [follow there](https://github.com/ValveSoftware/Source-1-Games/issues/6868) for updated information.
- If you find this useful and it works well for you, please ⭐ this repository and share with others in the community.
- If you would like to support my work and [servers](https://stats.scorpex.org/) I run in the community, consider [buying a coffee](https://help.scorpex.org/) ☕
  
[Back to top](#top)
