# Café Listening VR: notes for AI agents

Godot 4.4.1 OpenXR project (Quest Pro, GL Compatibility) for the ERVR paper. Read `README.md` for gameplay and project layout.

## Testing: what works and what doesn't
- **The Mac cannot run the game in XR.** Editor Play only shows a flat desktop window. Real testing means exporting an APK and installing it on the Quest (commands in `README.md`).
- **Do not run Godot `--script` / `--check-only` / `-s` headless runs.** They hang forever on this machine and print nothing; earlier sessions burned a lot of time on this. `--import` and `--export-debug` work fine.
- Godot and `adb` must run **outside the sandbox** (they write to `~/Library` and use the adb daemon). Sandboxed Godot crashes on log rotation.
- Nothing can be verified visually from the terminal. After a change, export, install, and ask the user what they see. Don't guess at layout and sizes repeatedly; make one change, deploy, and get feedback.
- **Keep adb usage minimal and bounded**: one export, one `adb devices`, one install, one launch. If a step fails, report the exact error rather than retrying. (The user's previous tool burned its whole token budget on adb loops.)
- If `adb install` prints "cannot connect to daemon", run `adb devices` once (it restarts the daemon) and install again. Check that the install printed `Success` before launching.
- Export error "A valid Java SDK path is required": Godot's Editor Settings → Export → Android → Java SDK Path got cleared. Set it to `/Users/apolo/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home`. The user does this in the editor; editing the settings file while the editor is open gets overwritten.

## Assets (important gotchas)
- **Never rename files in `assets/cafe/`.** The FBX finds its atlas and palette textures by their original file names. Renaming them made every prop render black and white.
- Props are not instanced from separate scenes; `scripts/cafe_assets.gd` pulls them out of the single pack FBX by name (spaces and case ignored) and fits them to a size.
  - Keep the importer's baked rotation but drop the position in the pack's grid, or props lie sideways.
  - Flat or wide items (plates, cups with saucers) must be sized by **longest side**, not height, or they come out huge.
  - Characters store unit scale on armature nodes, so measure the model through the whole node chain, not just the mesh AABB, or the customer is hundreds of meters tall.
- Prop names were taken from the FBX object list; a wrong name only logs a warning and leaves an empty spot.
- Customers come from `assets/characters/all_together.fbx`; outfits are the `<Name>_Body/_Head/_Legs/_Feet` meshes (`Formal` head is misspelled `Formad_Head`). Animation names look like `CharacterArmature|Walk`.
- **Licenses are unconfirmed** (see `ASSET_CREDITS.md`). The café pack is reportedly CC BY-ND 4.0. Don't push this repo publicly or distribute builds until that's sorted.

## Working style with this user
- They are testing on a real headset and react to what they see. Keep replies short and say plainly what is verified versus guessed.
- Commit only when asked. Don't commit the editor's stray reordering of `project.godot`.
- Stop and say so if a tool approach isn't producing output, instead of waiting on it repeatedly.
