<p align="right">
<img align="right" height="140" src="natsuk1.png?raw=true"/>
</p>

# natsuk1

iOS 27 only. Research project.

## Features

- Kernel offset viewer (iOS 27.0 / 24A437 reference data)
- Versioned offsets database in `natsuk1/Offsets/`
- Background keep-alive: silent audio + low-accuracy location
- Neon respring
- Device info panel
- Auto-run on launch

## Requirements

- iPhone running **iOS 27.0** (any minor)
- Sideload via AltStore / TrollStore / Sideloadly / Xcode

## Install

Download the latest `natsuk1.ipa` from the [development release](../../releases/tag/development) and sideload it.

## Build

```
brew install xcodegen ldid
xcodegen generate
xcodebuild -project natsuk1.xcodeproj -scheme natsuk1 -configuration Release -sdk iphoneos
```

## Credits

- [@flong69zxc-max](https://github.com/flong69zxc-max)
- [@murk-sus](https://github.com/murk-sus)
- [@eurogoth](https://t.me/eurogoth)
- [@asuka4scape](https://t.me/asuka4scape_developer)
