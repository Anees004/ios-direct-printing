REQUIRED FOR TESTFLIGHT / APP STORE
====================================

Apple will reject the build if the iOS app icon is missing.

Add this file to this folder:
  AppIcon-1024.png

Requirements:
- Size: 1024 x 1024 pixels
- Format: PNG (no transparency/alpha for App Store)
- Content: Your app icon (e.g. label, printer, or your logo)

Quick options:
1. Design in Figma/Sketch/Canva and export 1024x1024 PNG.
2. Use a free generator: search "iOS app icon generator" and upload a square image.
3. Use SF Symbol: in Preview or design tool, use a printer/label symbol on a colored square, export 1024x1024.

Then drag AppIcon-1024.png into the AppIcon.appiconset in Xcode (or place it in this folder and reopen the project).
