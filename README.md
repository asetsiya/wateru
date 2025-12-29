# Wateru

A physics-based fruit(or anything) merge puzzle inspired by *Suika Game*, but extended beyond a simple clone.  
Designed as a complete, playable game rather than a bare template, while still remaining flexible and hackable.

Built with **Defold**, targeting **Android** first but fully **cross-platform**.

## Screenshots
![g4](https://github.com/user-attachments/assets/66784297-027b-4ace-a4c7-8bda74aee22e)
![g3](https://github.com/user-attachments/assets/f845942b-d8a1-429a-8b79-e9ced5f75e0b)

## Features

### Gameplay
- Classic fruit-merge mechanics with improved physics (unlike the early version)
- Next fruit preview (unlike the early version)
- Significantly refined collision and merge logic
- Many physics-related bugs from early versions fixed
- Haptic feedback on merges (with adjustable intensity per device)


### Multiplayer (Local Network / LAN)
- Local network multiplayer for **two devices**
- No rooms, no lobbies, no IP input, no setup
- Devices automatically discover each other on the same network
- Tap a player → send invite → accept → game starts
- Works reliably across:
  - Standard Wi-Fi
  - Hotspot
  - Wi-Fi Direct
- Tested against various edge cases and unstable network scenarios

#### Multiplayer Game Modes
- **Suicide Mode**: the player who drops the fruit loses
- **Score Target Modes**: first to reach 1000 / 2000 / 3000 points wins
- **Character Unlock Mode**: first to unlock a specific character wins
- Game mode system is modular and easy to extend


### Online Features (Optional)
- **Supabase-powered scoreboard**
- Login & register system included
  - Requires Supabase URL and API key
  - Not designed with strict security guarantees (acceptable for hobby projects)
- Scoreboard is accessible **only when logged in**
- Fully optional: the game runs fine without Supabase


### Tricks System
- In-game **Tricks** menu, usable by spending score during a session
- Currently included:
  - Tap any fruit to instantly destroy it
- Designed to be extensible; adding new tricks is straightforward


### Polish & Extras
- Considerable UI and gameplay polish
- Designed to feel like a finished game, not just a starter project
- Assets are intentionally goofy placeholders and expected to be replaced
- Includes a few hidden, slightly absurd easter eggs


## Project Philosophy
- Open source
- Playable out of the box
- Easy to modify, extend, or commercialize
- Suitable both as:
  - a learning reference
  - a base for your own polished release


## License
MIT License.  
Use it, modify it, ship it, sell it.
