# Café Listening VR

Quest Pro café prototype. Customers walk up to the counter and order a coffee in Spanish; make it in the right cup size, then release the cup at **ENTREGA**.

## How to play

1. A customer walks in and says their order (for example, "Quisiera un café mediano con leche, sin azúcar.").
2. Grab the cup that matches the size: **pequeño** (espresso cup), **mediano** (cappuccino cup) or **grande** (tall cup).
3. Touch **CAFÉ**, then **LECHE** and/or **AZÚCAR** as ordered. **LAVAR** empties the cup.
4. Release the cup at **ENTREGA**. A wrong drink gets a hint in Spanish; a correct one gets "¡Perfecto, muchas gracias!"
5. The cup flies to the customer and disappears, they wave and walk off, and the next customer (new outfit, new order) walks in. A fresh empty cup returns to its spot.

A cup that falls off the counter returns to its starting position.

## Project layout

- `scripts/main.gd`: order list, customer walk-in/out loop, station triggers, delivery checking, and scene dressing.
- `scripts/drink_cup.gd`: pickable cup; per-size models and liquid settings live in `SIZE_SPECS`.
- `scripts/cafe_assets.gd`: pulls named props out of the café pack and fits them to a target size; builds the customer character.
- `assets/cafe/`: café asset pack. Keep the original file names, because the FBX finds its atlas and palette textures by name.
- `assets/characters/`: Quaternius character FBXs (`all_together.fbx` is the one in use).

To add an order, add an entry to `ORDERS` in `scripts/main.gd`. To change customer outfits, edit `OUTFITS` (names come from the character FBX, such as `Casual` or `Formal`).

Desktop Play in the editor only shows the scene in a window, because Quest Pro needs the headset build below.

## Build on this Mac

- Open the project with Godot 4.4.1. The Godot OpenXR Vendors 4.3.1 add-on is included under `addons/`; the Quest export preset is `Quest Pro Debug`.
- Godot's Android export templates, Android SDK, and Java 17 are already installed on this Mac. Godot's Android export settings point to `/Users/apolo/Library/Android/sdk` and `/Users/apolo/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home`.
- The Android build template is installed locally in `android/build/` and ignored by Git. If it is missing after a fresh checkout, use **Project → Install Android Build Template** in Godot once.
- In Godot, use **Project → Export → Quest Pro Debug → Export Project**. Save the APK to `build/cafe-listening-quest-pro.apk`. Godot creates a debug-signed build for testing.

Or build from Terminal in this project directory:

```sh
mkdir -p build
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug 'Quest Pro Debug' build/cafe-listening-quest-pro.apk
```

Connect the Quest Pro with a USB data cable and allow USB debugging in the headset, then install and launch:

```sh
~/Library/Android/sdk/platform-tools/adb install -r build/cafe-listening-quest-pro.apk
~/Library/Android/sdk/platform-tools/adb shell am start -n org.ervr.cafelistening/com.godot.game.GodotApp
```

The APK and `android/build/` stay local; Git tracks the source and export settings. See [ASSET_CREDITS.md](ASSET_CREDITS.md) before distributing a build.
