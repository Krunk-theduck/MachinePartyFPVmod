<h1 align="center">MachinePartyFPV</h1>

<p align="center"><b>Made by J_axon and Krunk</b></p>

<p align="center">
  <img src="assets/banner.png" alt="MachinePartyFPV - a first person view mod for Machine Party" width="100%">
</p>

<p align="center"><b>Bring FPV to lobbies, minigames, deaths — and a full spectator system.</b></p>

**MachinePartyFPV puts you inside your own character in Machine Party.** Instead of the game's fixed third-person cameras, you see every minigame through your character's own eyes, look around freely with the mouse or a controller, watch your own death play out in first person, and stand around the lobby in first person while you wait. And when you're out, you get a complete **spectator system** — a proper third-person follow you can steer between players, a first-person view *through anyone's eyes*, and a free-fly camera.

It is a purely visual, client-side mod. It does not touch networking, it does not repack or modify the game's data files, and it works whether or not anyone else in your lobby has it — as host **or** client, in your own lobby or someone else's. It is styled with the game's own fonts and fits right in.

Created by **J_axon** and **Krunk**.

> **Credit required.** You are free to use MachinePartyFPV's code in your own projects under the MIT License. If you reuse any of it, you must credit **J_axon** and **Krunk** and keep the license notice included. Please keep that credit visible and easy to find, for example in your README, mod description, or in-game credits.

### A note on the project

MachinePartyFPV was built together by **J_axon** and **Krunk**. Krunk has since stepped away and is no longer actively working on the mod, so from here on **J_axon** is maintaining MachinePartyFPV and taking it forward. Krunk's work stays an equal, permanent part of the project: **Krunk keeps full and equal credit** for everything we made together, and the copyright and license are unchanged. Thank you, Krunk.

---

## Features

- **First person in every minigame** — see the game through your character's eyes, with free mouse and controller look, using the real head-bone rig (bob, smoothing, head hidden) so it feels native.
- **Full spectator system** — when you're out, choose how you watch: the game's own **third-person** camera that you can steer between players, a live **first-person view through another player's eyes**, or a **free-fly camera**. Cycle players with on-screen arrows, bumpers, or the D-pad. Works with the FPV toggle on **or** off.
- **Player name + role tags** — the spectate bar names who you're watching and tags their role (**RUNNER / HUNTER / INFECTED / SURVIVOR**), with cycle arrows to move between them.
- **Duck Hunt hunter spectating** — watch the hunter's *actual* first-person view: their arms, gun, aim, and scope zoom, exactly as they see it.
- **Lobby FPV** — stand in the waiting room in first person and look around while everyone gets ready.
- **First-person deaths, then a clean spectate** — you watch your own death happen in first person (the body drop, the exploding-collar hat, the crush), then it hands off to the spectator system.
- **Finishing is not dying** — finish your food, finish your smoke, or survive a Recycle round and you stay in first person with look-around. Only a *real* death sends you to spectate.
- **Smart per-game handling** — every minigame gets death timing, camera limits, and behavior tuned to how it actually plays (details below).
- **Firearm Factory recipe HUD** — an animated build-order bar shows the parts you need next, and swaps to a dedicated gun panel (with a live reload bar) once you've built and are holding the gun.
- **Inside Job infection overlay** — a pulsing green vignette and flash the instant you're infected, mirroring the game's own blood overlay but in green.
- **Bot-friendly** — plays nicely with AI bots (e.g. the Offline Bots mod); spectating a bot is de-jittered so their movement stays smooth.
- **Two HUD styles** — pick the detailed art or a clean, simple box-and-bar look with one toggle.
- **Separate mouse and controller sensitivity** — two independent sliders, saved between sessions.
- **Full controller support** — everything, including the whole spectator system, is playable on a controller, and the on-screen button hints flip live between keyboard and controller as you switch.
- **Everything is optional and remembered** — the core features are toggles in the in-game FPV Settings menu, and your choices are saved.

MachinePartyFPV is a pure GDScript mod loaded through the **[Machine Party Mod Loader](https://github.com/Krunk-theduck/MachinePartyModLoader)**.

---

## How it works

Machine Party is normally a third-person game: each minigame has one fixed camera looking at the play area. MachinePartyFPV runs entirely on your own machine and, while you're playing, quietly parks the game's camera and drives its own camera from your character's head bone instead. Nothing is sent over the network, and no game files are changed.

Because it is 100% local and visual:

- **It works with vanilla players.** You do not both need it. Other players see the normal game; you see first person. Nothing about the match changes for anyone else.
- **It works the same as host or client.** Everything — FPV, deaths, the spectator system, the per-game behaviors — behaves identically whether you're hosting or joining, in your own lobby or someone else's.
- **It never affects gameplay, scoring, or hit detection.** It only moves the camera and draws a little HUD on your screen.

---

## First person, everywhere

### In the lobby

<p align="center">
  <img src="assets/lobby-fpv-1.png" alt="First person in the Machine Party lobby, looking down at your own body" width="49%">
  <img src="assets/lobby-fpv-2.png" alt="First person in the lobby looking around the waiting room" width="49%">
</p>

Turn on **Lobby FPV** and you can stand in the waiting room in first person. **Hold Shift** (keyboard) or the **Left Bumper** (controller) to look around from your character's eyes; let go and the view stays where you left it. It works in both the online lobby and the local couch lobby.

### In the minigames

<p align="center">
  <img src="assets/minefield-fpv.png" alt="First person in Minefield, holding the mine detector with the collar belt HUD" width="49%">
  <img src="assets/table-manners-fpv.png" alt="First person in Table Manners, eating peas off the plate" width="49%">
</p>

Every minigame is played from your character's eyes. You look with the mouse or the right stick. In the seated games the view is gently limited so you can look around your workstation without whipping all the way around; in the fast, moving games it's fully free, and in the movement games your character walks in the direction you're looking.

---

## The spectator system

When you're eliminated (or you leave first person), MachinePartyFPV gives you a real spectator setup instead of a single fixed camera. It works whether the **First Person View** toggle is on or off, and it behaves the same as host or client.

There are three ways to watch, and you move between them freely:

1. **Third person (default).** This is the game's *own* third-person spectator camera — the exact vanilla framing and feel — except the on-screen arrows let you steer **which player it follows**. In games that have no built-in spectate switcher, the mod re-centers that same camera on whoever you pick, so cycling always moves you to a different player at the game's own angle.
2. **First-person view (through their eyes).** Watch any player in first person, pinned to their head with the same rig your own FPV uses. You look around **yourself** — hold **Shift** (keyboard) or **LB** (controller) and move the mouse/right stick — clamped like the lobby view, so you're never yanked around by their aim.
3. **Free-fly camera.** A detached, no-clip flying camera. It spawns at one of the players, moves faster than a walk, and lets you look around fully. Move with **WASD** / left stick, hold **Shift** / **LB** to look, and it stays in free-fly until *you* leave it — clicks won't kick you out. Toggle it any time with **F5** or the on-screen **Free-fly cam** button (**X** on a controller).

Along the bottom of the screen, a name plate shows **who you're watching** and a **role tag** for the mode you're in:

- **RUNNER / HUNTER** (Duck Hunt), **INFECTED / SURVIVOR** (Inside Job), and so on.
- **◀ ▶** arrows (or **LB / RB** on a controller, or the D-pad) cycle to the next player.
- In free-fly it reads **In Free Cam mode**; in games with no selective spectating it reads **Default View**.

<p align="center">
  <img src="assets/minefield-spectate.png" alt="Steering the third-person spectator camera between players" width="80%">
</p>

**Duck Hunt hunter view.** Spectate the hunter and you see their genuine first-person view — arms, gun, aim, and scope zoom — the same picture the hunter has, with their laser sight hidden the way it is for them.

**Train Hazard.** This one keeps the game's original default spectating (no player-cycling arrows); you still get the free-fly camera and first-person view as options.

Everything here is on a controller too: **cycle** with the bumpers or D-pad, **toggle first-person spectate** and **free-fly** with the face buttons, and **fly** with the sticks and triggers. The button hints on screen switch between keyboard and controller glyphs the moment you change input.

---

## Deaths, finishing, and spectating

<p align="center">
  <img src="assets/firearm-factory-spectate.png" alt="Spectating another player after a Firearm Factory death" width="49%">
  <img src="assets/inside-job.png" alt="Inside Job in first person with the green infection overlay" width="49%">
</p>

Dying is the fun part. You ride your own death out in first person, and then it hands over to the spectator system above. Each game gets timing that matches its animation:

- **Minefield** — your exploding collar pops your hat off; the camera rides the flying hat for about 5 seconds, then hands to spectate.
- **Firearm Factory / Table Manners / Duck Hunt** — you watch your body drop for a few seconds, then hand to spectate.
- **Wrong Way / Debris Platform** — you ride the crush or the fall, then hand to spectate.
- **Forklift** — getting eliminated keeps you in first person on your own vehicle; the view only cuts away for the crane "take the package away" tie scene, and comes back next round.
- **Duck Hunt** — reach the exit as the runner and it fades to black, then to spectate; when a round or the whole game ends, all the spectating cleanly shuts off.

**Finishing is not dying.** If you complete your task instead of losing, you stay in first person with full look-around — you're never yanked to spectate for surviving:

- **Table Manners** — finish your food and keep looking around.
- **Recycle** — you stay in first person while *another* player is crushed and through the score / loser-pick; you only leave first person when it's actually *you* who gets crushed.
- **Smoke Break** — when the timer ends, everyone freezes while the trolley aims. You keep looking around the whole time, and you only leave first person the moment the trolley actually **shoots you**. Survivors keep looking around into the next round.
- **Inside Job** — being infected doesn't end your first person; you keep playing (and looking around) through the transformation.

---

## The Firearm Factory recipe HUD

In Firearm Factory you build a gun from a sequence of parts, and MachinePartyFPV draws a first-person **recipe bar** so you always know what's next:

- One slot per step, revealed one at a time like the in-world holographic recipe.
- The part you need **right now** shows as an animated icon — a spinning gear, a bouncing spring, and so on — with a slow **strobing red bar** underneath it.
- Steps you've already placed show in solid color and stop animating; later steps stay hidden until you reach them.
- Once you've **built the gun and are holding it**, the bar swaps to a dedicated **gun panel**: it shows the gun, reads **READY**, and when you fire it flips to **RELOADING** with a live reload progress bar until you're ready again.

The recipe bar only appears for *you* while you're the one at the workstation.

---

## The FPV Settings menu

Open the pause menu (**Esc**) and you'll find an **FPV Settings** button in the MODS section. It opens a panel with the core options:

- **First Person View** — the master on/off switch. (The spectator system still works with this off.)
- **In-Depth HUD Art** — on for the detailed collar belt and burning cigarette; off for a clean, simple box and bar. The round timer shows either way.
- **Lobby FPV** — first person in the waiting room (hold Shift / Left Bumper to look).
- **Experimental: Hold Shift to Re-lock View** — press Shift (keyboard) or the Left Bumper (controller) to re-center your look in the seated games.
- **Mouse Sensitivity** and **Controller Sensitivity** — two separate sliders. Each one only affects its own input, and both are saved.

Every setting is remembered between sessions.

---

## Controls

### Playing

| Input | Action |
|---|---|
| **Mouse** | Look around (while the game has your cursor captured) |
| **Right stick** | Look around on a controller |
| **Shift** (kb) / **Left Bumper** (pad) | Hold to look in **Lobby FPV**; also re-centers your view if the experimental re-lock toggle is on |
| **Esc** | Pause menu → **FPV Settings** |

### Spectating

| Input | Action |
|---|---|
| **◀ ▶** buttons / **LB · RB** or **D-pad** (pad) | Cycle which player you're watching |
| **Switch to FPV view** button / **Y** (pad) | Toggle first-person view of the watched player |
| **Free-fly cam** button / **X** (pad) / **F5** (kb) | Toggle the free-fly camera |
| **WASD** / left stick | Move in free-fly |
| **Shift** / **LB** (hold) + mouse / right stick | Look around in first-person spectate or free-fly |

Mouse and controller sensitivity are set independently in the FPV Settings menu.

---

## The HUD

MachinePartyFPV draws a small amount of first-person HUD. The in-world art pieces are optional through the **In-Depth HUD Art** toggle:

- **Minefield collar belt** — a leather belt with a metal buckle whose warning light is your exploding collar. It reads your live mine proximity, going from green when you're safe to red as you close in, and pulses when it's about to blow. (Simple mode: a colored box.)
- **Smoke Break cigarette + timer** — a lit cigarette that burns down as you smoke, with a glowing ember and a wisp of smoke, plus a red digital round timer at the top of the screen that matches the game's own clock. (Simple mode: a plain bar. The timer always shows.)
- **Firearm Factory recipe bar / gun panel** — the animated build-order bar and the READY/RELOADING gun panel described above.
- **Damage flash** — a quick red flash and a small camera jolt when you take a non-fatal hit.
- **Last-life vignette** — a pulsing red vignette around the screen when you're down to your final life.
- **Inside Job infection overlay** — a pulsing green vignette and a flash the instant you're infected, behaving exactly like the game's blood overlay but green (and only on the player who's actually been mutated).

---

## Works with vanilla players

MachinePartyFPV is entirely client-side and visual, so it is fully cross-compatible with players who don't have it. You do **not** both need it to play together. It changes only what *you* see; everyone else sees the normal game, and the match, scoring, and connection are untouched. You can host or join vanilla players exactly as normal, and everything works the same on either side.

---

## Installation

MachinePartyFPV runs through the **[Machine Party Mod Loader](https://github.com/Krunk-theduck/MachinePartyModLoader)** by Krunk-theduck. You install the loader once, then drop MachinePartyFPV into the mods folder. Because the mod is purely visual and local, **only you** need it installed to use it, you can play with vanilla players freely.

### Step 1: Install the Machine Party Mod Loader

1. **Find your game folder.** In Steam, right-click **Machine Party** in your library, choose **Manage**, then **Browse local files**. Open the **`Machine Party_Windows`** folder. It contains **`Machine Party.exe`** and **`Machine Party.pck`**.
2. **Download the loader.** Get **`MachinePartyModLoader.exe`** from the loader's releases page (extract it first if it comes as a `.zip`):
   https://github.com/Krunk-theduck/MachinePartyModLoader/releases
3. **Place the loader.** Drag **`MachinePartyModLoader.exe`** into that game folder so it sits right next to **`Machine Party.exe`** and **`Machine Party.pck`**.
4. **Run it.** Double-click **`MachinePartyModLoader.exe`**. If Windows shows a security warning, click **More info** then **Run anyway**. A command window shows the setup progress and closes when it's done. This creates a **`mods`** folder in your game directory.

### Step 2: Install MachinePartyFPV

1. Download **`Jarunk-MachinePartyFPV.zip`** from this repo's releases page:
   https://github.com/Ghostx10742/MachinePartyFPVmod/releases
2. Extract it into the **`mods`** folder inside your game folder, so you end up with the folder (not a zip) at:
   ```
   <your Machine Party folder>\mods\Jarunk-MachinePartyFPV\
   ```
   That folder should contain `fpv_controller.gd`, `main.gd`, `mod.json`, and the `overrides` and `textures` folders.

### Step 3: Launch and play

1. **Start Machine Party from Steam exactly like you always have.** The mod loader hooks in automatically, there's no special shortcut.
2. To check the loader is active, press the backtick key **`` ` ``** in-game; a small debug console appears if it's working.
3. Press **Esc** to open the pause menu and click **FPV Settings** to confirm the mod loaded. If that button is there, you're good, everything is on by default.

To uninstall, delete the `Jarunk-MachinePartyFPV` folder from `mods`. To play fully vanilla again, remove the loader (or just delete the mod folder).

---

## Game updates

MachinePartyFPV runs on top of the Machine Party Mod Loader, so a future Machine Party update can temporarily break the loader (and with it, this mod). If that happens, mods may stop loading, or a specific minigame's camera may look off if the game changed how it's built.

If that happens, don't panic and don't keep reinstalling. Wait for the mod loader (and this mod) to push an update, then update and launch again. Your normal, unmodded game is never affected.

---

## Building from source

MachinePartyFPV is pure GDScript, so there is no compile step. The Machine Party Mod Loader loads mods as **loose folders**, so "building" just means zipping the mod folder for release, so that extracting it into `mods` gives you `mods/Jarunk-MachinePartyFPV/`.

Requirements: git, and Python 3 (used only to package the zip, and for the small image tools).

1. Clone the repo:
   ```bash
   git clone https://github.com/Ghostx10742/MachinePartyFPVmod.git
   cd MachinePartyFPVmod
   ```
2. Build the release zip:
   ```bash
   python build.py
   ```
   This writes `dist/Jarunk-MachinePartyFPV.zip`.
3. Install it for testing: extract the zip into your game's `mods` folder (so you get `mods/Jarunk-MachinePartyFPV/`), then launch Machine Party normally from Steam.

Dev loop: edit the GDScript in `Jarunk-MachinePartyFPV/`, copy the folder into the game's `mods` folder (or re-run `build.py` and extract), and relaunch.

Repo layout:

```
Jarunk-MachinePartyFPV/    the mod source (fpv_controller.gd, main.gd, mod.json, overrides/, textures/)
dist/                      the built, ready-to-install zip
assets/                    readme screenshots
recipe_src/                source art for the recipe HUD sprites
build.py                   packages the mod into dist/
tools_prep_recipe.py       preps the recipe sprite sheets
```

Almost all of the mod lives in `Jarunk-MachinePartyFPV/fpv_controller.gd`, one file that finds your local player each frame, drives the first-person camera, draws the HUD, runs the spectator system, and handles the per-game camera and death behavior.

---

## Credits

- Created by **J_axon** and **Krunk**.
- Testing by **AL3N** and **TunaFeesh** — thank you for helping shake out the bugs.
- Loaded through the **[Machine Party Mod Loader](https://github.com/Krunk-theduck/MachinePartyModLoader)** by **Krunk-theduck**.

MachinePartyFPV is now maintained by **J_axon**. Krunk has stepped away from active development but keeps **full and equal credit** for the work we built together.

---

## License

MachinePartyFPV is released under the **MIT License**. You are free to use, modify, and include this code in any project, including your own mods, for free. The one requirement is that you keep the credit to **J_axon** and **Krunk** (the copyright and permission notice from the LICENSE file) included with the code. Please also credit both somewhere visible in any project that reuses it. See the [LICENSE](LICENSE) file for the full terms.

---

## AI disclosure

AI was used during the development of this project, mainly for revisions, inquiries, and things I just did not know. This does not mean the mod was fully AI-made, but rather that AI was used as part of the development process. I wanted to disclose this for people who may have a problem with AI being involved and may not want anything to do with it. Even though I disagree with your view on AI, I still respect your opinion on the subject.
