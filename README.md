# FillRaidBots

[![Version](https://img.shields.io/github/v/release/pumpan/FillRaidBots?color=blue&label=version)](https://github.com/pumpan/FillRaidBots/releases)
![WoW Version](https://img.shields.io/badge/WoW-1.12.1-ff69b4)
![License](https://img.shields.io/badge/license-MIT-green)
[![Latest ZIP](https://img.shields.io/badge/dynamic/json?color=success&label=Latest&query=$.assets[0].download_count&url=https://api.github.com/repos/pumpan/FillRaidBots/releases/latest)](https://github.com/pumpan/FillRaidBots/releases/latest)
<a href="https://www.paypal.com/donate/?hosted_button_id=JCVW2JFJMBPKE" target="_blank">
    <img src="https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif" 
         alt="Donate with PayPal" style="border: 0;">
</a>
<a href="https://www.paypal.com/donate/?hosted_button_id=JCVW2JFJMBPKE" class="paypal-button" target="_blank">
    💙 Support Me with PayPal
</a>

## 📋 Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Presets](#presets)
- [Editing Presets or Suppress Bot Messages](#editing-presets-or-suppress-bot-messages)
- [Changelog](#changelog)
- [License](#license)
- [Contact](#contact)

---

## 🧠 Overview

**FillRaidBots** is an advanced addon for the **PartyBot Command Panel (PCP)** for **World of Warcraft 1.12.1**.

It helps you:
- Quickly fill raids with bots
- Use optimized presets for bosses and instances
- Automatically manage bots (remove, refill, organize)
- Customize everything directly in-game

## 🎬 Quick Tutorial

<p align="center">
  <a href="https://www.youtube.com/watch?v=vJozbfeNEno">
    <img src="https://img.youtube.com/vi/vJozbfeNEno/maxresdefault.jpg" width="600">
  </a>
</p>

---

## 🛠️ Installation

1. **Download the Addon:**  
   - Download the ZIP file from GitHub.
   
    👉👉👉 [![⬇ DOWNLOAD](https://img.shields.io/github/downloads/pumpan/FillRaidBots/total?style=for-the-badge&color=00b4d8&label=⬇+DOWNLOAD)](https://github.com/pumpan/FillRaidBots/releases) 👈👈👈

2. **Extract Files:**  
   - Extract the contents to your WoW addons directory, typically located at:
     ```
     World of Warcraft/Interface/AddOns
     ```
   - Make sure the folder is named `FillRaidBots`.

3. **Enable the Addon:**  
   - Launch WoW and go to the AddOns menu from the character selection screen.  
   - Ensure that the addon is enabled in the list.

4. **If you are having troubles**
   - 📘 [How to install addons](https://github.com/pumpan/howtoinstalladdons/wiki)

## ⚡ Features (Core Behavior)

- Automatically creates:
  - **Fill Raid button**
  - **Kick All button**
  - **Refill button**
- Appears when opening PartyBot Command Panel

<p align="center">
   <img src="/ScreenShots/newbuttons.png">
   <img src="/ScreenShots/fillraidbots.png" width="400">
</p>

### 🧩 Party vs Raid Behavior

- The addon dynamically decides whether to stay in a party or convert to a raid

Rules:
- If total members (players + bots) ≤ 5 → stays a party
- If total members > 5 → converts to a raid

👉 No unnecessary raid conversion  
👉 Works even when filling an existing group of real players

---

### 🟢 Fill Raid Button

- Opens the main configuration UI
- Lets you:
  - Manually set number of bots per role
  - OR choose from predefined presets

<p align="center">
  <img src="/ScreenShots/fillraidbots3.png" width="400">
</p>

---

### 🔴 Kick All Button

- Removes all bots from the raid
- Keeps one bot to prevent disband
- ✅ **Does NOT remove real players**

---

### 🔁 Refill Raid Button

- Replaces missing or dead bots automatically
- Uses improved **multi-pass system**:
  - Continues until raid is fully restored
  - Handles delayed bot removal correctly

---

### 🧠 Smart Fill System

- `Ctrl + Alt + Click boss` → loads correct preset
- `Ctrl + Alt (no target)` → loads preset based on instance
- If multiple presets match → **popup appears at cursor**

---

### ⚙️ Auto Remove Features

- **Auto Remove First Bot**
  - Removes the first bot (usually bad gear)

- **Remove Dead Bots Button**
  - Appears automatically when bots die

- **Auto Remove Option (Settings)**
  - Can automatically:
    - Remove first bot
    - Remove dead bots

---

### ⚡ Fast Fill

- Quickly fills the raid using optimized presets
- Minimal setup required

---

## 🧩 Preset System

---

### 📦 Built-in Presets

Supports:
- Naxxramas
- Blackwing Lair
- Molten Core
- AQ40 / AQ20
- Zul'Gurub
- Onyxia

Each preset includes:
- Tanks / Healers / DPS distribution
- Tooltip auto-generation
- Boss mapping support

### 🧠 Advanced Bot Configuration (NEW)

Configure bots directly before filling:

- Paladin blessing assignments
- Shaman totem setups
- Mage Frost/Fire spec selection
- Role icons in configuration UI
- Supports:
  - Same setup for all
  - Individual setup per bot
  - 50/50 Mage spec mode
  - Copy/Paste Shaman setups
- Saved directly in presets

<p align="center">
  <img src="/ScreenShots/totems.png" width="200">
  <img src="/ScreenShots/blessings.png" width="200">
</p>
---

### 🧠 Smart Preset Detection (`Ctrl + Alt`)

<p align="center">
  <img src="/ScreenShots/fastfill.png">
</p>

Old system only supported bosses, for example `Boss Name`, `Another Boss`.

Presets now also support:

👉 **Instance-based detection**

- If no target → uses instance name
- If multiple matches → shows selection popup

---

### ✏️ Editable Presets (In-Game UI)

You can now:
- Edit presets directly in-game
- Save changes
- Save As (create new preset)
- Delete presets
- Restore defaults

---

### 💾 Export / Import

- Export all presets + settings
- Share between accounts
- Import directly in-game

---

## 🎥 Tutorial Videos System

<p align="center">
  <img src="/ScreenShots/tutorials.png">
</p>

- Integrated tutorial system via `Tutorials.lua`
- Displays boss-specific guides inside the addon

Supports:
- Alliance / Horde versions
- VIP / non-VIP
- Multiple creators per boss
- Smart fallback system

---

## ⚙️ Settings

Fully rebuilt settings system:

<p align="center">
  <img src="/ScreenShots/frbsettings.png">
</p>

---

### 🎛️ UI Customization

<p align="center">
  <img src="/ScreenShots/themes.png">
</p>

- Button themes
- Button size slider
- Button spacing slider
- Layout modes:
  - Fixed
  - Free
  - Relative

---

### 🔧 Feature Toggles

- Click-To-Fill
- Zone Presets
- Tutorial Links
- Debug Messages
- Auto Remove Bots
- Loot Type
- Auto Repair (VIP only)
- Auto Join Guild
- Auto Mute Sound
- Use VIP Presets

---

### 📍 Zone Presets

- Detects your current instance / zone
- Opens the correct preset list automatically
- Helps speed up filling even without targeting a boss

---

### 🐞 Debugger

- Dedicated debugger window
- Cleaner debug logging
- Better visibility while testing and troubleshooting

---

## 🚀 Usage

1. **Open the PartyBot Command Panel**  
   - The addon automatically creates and opens the Fill Raid / Kick All / Refill buttons.

2. **Configure the Raid**  
   - Click **Fill Raid** to open the main frame.  
   - Enter manual values or choose a preset.

3. **Apply Presets**  
   - Use the preset list for bosses and instances.

4. **Kick All Bots**  
   - Removes all bots while keeping one bot so the raid does not disband.

5. **Refill Raid**  
   - Replaces missing bots after deaths or removals.

6. **Adjust Settings**  
   - Open settings to control automation, debug tools, layout, presets, and more.

7. **Slash Commands**
   - You can create macros for the following commands:
     ```
     /frb - for available commands
     /frb ua or /frb uninvite all – Uninvite all raid members but saves Friends and guild members.
     /frb (preset) – Fills the raid with the preset.
     /frb open – Open the Fill Raid frame.
     /frb rdb - Removes dead bots.
     /frb refill – Refill the raid.
     /frb fixgroups – Fix raid groups.
     ```

## 🗺️ Presets

The addon includes optimized presets for several dungeons and raids:

- **Onyxia:** 2 warrior tanks, 2 paladin healers, rest mages.
- **Molten Core (MC):** Detailed presets for each boss, including tanks, healers, and DPS roles.
- **AQ20:** Various presets for different bosses.
- **Zul'Gurub (ZG):** Specific presets for each boss, including tanks, healers, and DPS roles.
- **Blackwing Lair (BWL) and AQ40:** Configurations for raid encounters.

## 📝 Editing Presets or Suppress Bot Messages

- Suppressed messages can be edited directly in-game through the **Suppress** editor.
- Presets can be edited directly in-game through the preset editor.
- Advanced users can still review the addon data in `Presets.lua`, `Tutorials.lua`, and related files.

## 📅 Changelog

### **FillRaidBots 5.1.0**

- Advanced Paladin/Shaman/Mage configuration system  
- Paladin blessing assignment UI  
- Shaman totem assignment UI  
- Mage Frost/Fire spec system  
- 50/50 Mage spec mode  
- Copy/Paste Shaman setups  
- Role icons in bot configuration UI  
- Improved preset botSettings saving/loading  
- Moveable bot configuration windows  
- ESC support for configuration frames  
- Improved Classic (1.12.1) compatibility  
- Better spell tooltips and icon handling  
- Added support for "all" zone presets  
- Multiple UI and preset system fixes

### **FillRaidBots 5.0.0**
🆕 Major Changes (From Old Version)

    Instance-based preset detection
    Ctrl+Alt with no target support
    Preset selection popup at cursor (ctrl+alt)
    Tutorial video system
    Full UISettings overhaul
    Improved refill logic (multi-pass, and better tank detection)
    Editable presets UI
    Export / Import system
    Debug improvements
    Button layout & movement rewrite
    Dynamic raid size / spots left system

### **FillRaidBots 4.0.2**
🔄 Version updated to 4.0.2 — This update introduces bug fixes  
🐞 Fixed a critical localization bug where SendChatMessage could fail on non-English clients.  
Chat messages now always use locale-independent chat type tokens, ensuring full compatibility with all languages.

### **FillRaidBots 4.0.1**
🔄 Version updated to 4.0.1 — This update introduces bug fixes.  
🆕 Fixed handling of new bot names containing an asterisk (`*`).  
🔍 Improved detection of raid members as bots based on the asterisk in their names.

### **FillRaidBots 4.0.0**
🔄 Version updated to 4.0.0 — This update introduces major UI enhancements, in-game editing features, export/import options, and improved bot handling. It's a substantial quality-of-life release deserving of a full version bump.

🆕 Added: Editable raid composition presets directly within the in-game UI.  
🆕 Added: In-game UI for managing suppressed bot messages.  
🆕 Added: Export/import support for presets and suppressed messages across accounts.  
🆕 Added: Auto Repair feature (VIP only). Repairs your gear automatically at vendors.  
🆕 Added: Option to auto-join the SoloCraft guild.  
🆕 Added: Simplified reload command — use `/reload`, `/rl`, or `/reloadui`.  
🆕 Added: Party bot logic—groups with fewer than 5 bots stay as a party, ideal for leveling.  
🆕 Added: More accurate "Raid Filling Complete" message, reflecting the true raid state.  
🆕 Added: Escape key now properly closes the FillRaid UI.  
🆕 Added: Faction-based class filtering (e.g., hides Paladins for Horde, Shamans for Alliance).  
🆕 Added: Class headers in the UI for better visual organization (e.g., Warriors, Mages).  
🆕 Added: Auto-remove bot option — can remove first and/or dead bots automatically.

### **FillRaidBots 3.0.0**
🔄 Version updated: to 3.0.0, since FillRaidBots now introduces multiple usability upgrades, UI options, new commands, and extended compatibility, it’s a big leap forward, making 3.0.0 the right version number.

🆕 Edited: you can now use `/frb (bossname or part of bossname eg: ony or /frb mage group)` (suggestion by Gemma)  
🆕 Added: A new feature to add preset bots with `Ctrl + Alt + Mouse Click` on bosses  
🆕 Added: Settings to choose if you want big or small (round) buttons (Fill Raid, Kick All etc)  
🆕 Added: You can now select automatic loot type on raid creation in the settings menu.  
🆕 Added: Works with both PCP and PCPRemake  
🆕 Added: You can now reload UI with `/rl` `/reloadui` `/reload`

**Improvements:**  
🆕 Edited: you can now use `/frb (bossname or part of bossname eg: ony)` instead of `/frb fill`

### **Previous Versions**

## Changelog
**FillRaidBots 2.1.0**

🔄 Version updated: to 2.1.0, introducing multiple improvements to performance, user experience, and new features.  
🆕 Added: A Credits frame showcasing everyone who has helped in the development of the addon.  
🆕 Added: Slash commands to improve raid management:
- `/frb ua` or `/frb uninvite all` – Uninvite all raid members.
- `/frb fill` – Automatically fill the raid.
- `/frb open` – Open the Fill Raid frame.
- `/frb rdb` - Removes dead bots
- `/frb refill` – Refill the raid.
- `/frb fixgroups` – Fix raid groups.

🆕 Fixed: Players on the raid leader's friend list are no longer removed when adding bots, removing dead bots, or using the "Kick All" button (previously, this only applied to guild members).

**Improvements:**
- Debug messages are now separated from commands, enhancing command responsiveness and speed.
- Enhanced the process of matching player names, fixing an issue where a mismatch would cause a nil value error.

**Bug Fixes:**
- Fixed an error where player names weren’t matched, which previously led to nil values.

**FillraidBots 2.0.2**

🔄 Version updated: to 2.0.2, marking this as a major update due to significant new features and functionality improvements.  
🆕 Now detects the player's faction and loads the appropriate presets for Horde or Alliance.  
🛠 Improved: Healing sorting.  
🆕 Improved: Made the process of adding bots a little faster.  
🆕 Added: Bots are now added in a new way: healers are added first, sorted into different groups, and then all other classes are added.  
🛠 Fixed: Adjusted and fixed some presets for better functionality.  
🆕 Added: A debugger window for when debugging is enabled. All debug messages are now sent here instead of cluttering the chat window.  
🆕 Added: A version checker that notifies you if a newer version of the addon is available.  
🆕 Added: Logic to distribute healers evenly across the raid when bots are added.  
🆕 Added: Class and role detection in the raid, enabling new functionality such as managing bots based on their roles.  
🆕 Added: A new "Refill Raid" button, which replaces bots that die and are removed during gameplay.  
🛠 Fixed: The `/uninviteraid` slash handler to prevent conflicts with WoW's native commands like `/kick` and `/uninvite`, which were unintentionally uninviting the entire raid. (Reported by Gemma)  
🛠 Fixed: Since the latest server update, which prevents adding bots while in combat, an issue occurred where adding certain bots, such as warriors or hunters, caused you to enter combat for a few seconds. This created a problem where the addon attempted to add bots when they couldn't be added. I have now fixed it so that the addon detects when you're in combat and pauses until you're out of combat.  
🛠 Added: The ability to move the 'Fill Raid' and 'Kick All' buttons if this is enabled in the settings.  
🛠 Added: A version number to the FillRaidFrame so that it's easier to see which version you're using.

## 📜 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## 📧 Contact

For any questions or issues, please open an issue on GitHub or contact the repository owner.
