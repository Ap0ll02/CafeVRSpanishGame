# Café Listening VR

First playable Quest Pro prototype: grab the blue cup, touch **CAFÉ** and **LECHE**, skip **AZÚCAR**, then release the cup at **ENTREGA**. A correct order gets “¡Perfecto, muchas gracias!” The cup returns to its starting position if it falls off the counter.

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
