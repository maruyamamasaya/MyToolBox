# MyToolBox app icon

Generated 2026-10-15 using the built-in image_gen tool. Original artwork: `source.png`. No reference images or third-party artwork supplied. Transparent exterior preserved when resized with macOS sips. The generated master is retained at its original resolution.

Final prompt:

> Use case: logo-brand. Asset type: production macOS app icon for MyToolBox, a local system monitor. Create one polished square 1024x1024 icon: a simple recognizable toolbox with a handle and a small luminous system-monitor waveform integrated on its front. Native macOS aesthetic, restrained dimensional depth, clean silhouette, readable at small sizes. Center the toolbox on a rounded-square icon tile with comfortable margins. No text, letters, numbers, watermark, extra tools or mockup. Transparent exterior outside the rounded-square tile. This is the icon artwork itself, not a screenshot.

Run `python3 scripts/build_icon.py` from the repository root to regenerate `Resources/MyToolBox.icns`. Intermediate iconset PNGs are saved under `build/MyToolBox.iconset`. Xcode bundles the ICNS; Info.plist CFBundleIconFile points to it. Normal app builds do not call image generation or use a remote service.
