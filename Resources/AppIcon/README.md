# MyToolBox app icon

Generated 2026-10-23 using the built-in image_gen tool. Original artwork: `source.png`. No reference images or third-party artwork supplied. Transparent exterior preserved when resized with macOS sips. The generated master is retained at its original resolution. The main app uses a freestanding blue toolbox without a white border or background tile; individual tool icons are unchanged.

Final prompt:

> Create a refined production macOS app icon for MyToolBox. A single cobalt blue toolbox with a dark navy integrated handle, clean rounded geometric silhouette, subtle premium dimensional shading. Small cyan system-monitor pulse integrated directly on the front, no screen bezel. Two understated dark blue latches. Toolbox fills canvas comfortably and remains very legible at 32px. Transparent background, freestanding toolbox silhouette. Absolutely NO white border, NO white outline, NO rounded-square background tile, NO surrounding frame, NO text, NO extra tools, NO mockup. Centered square 1024x1024 icon artwork. Restrained modern blue palette, crisp elegant minimal design.

Run `python3 scripts/build_icon.py` from the repository root to regenerate `Resources/MyToolBox.icns`. Intermediate iconset PNGs are saved under `build/MyToolBox.iconset`. Xcode bundles the ICNS; Info.plist CFBundleIconFile points to it. Normal app builds do not call image generation or use a remote service.
