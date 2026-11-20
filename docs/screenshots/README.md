# Spacer screenshots

These are captures of the running macOS application with synthetic demonstration files, not generated UI mockups.

- `disk-usage.png`: free-space display, folder sizes and a two-level circular disk usage chart.
- `folder-navigation.png`: browsing a subfolder with clickable path breadcrumbs.
- `cleanup-suggestions.png`: reviewable recommendations for old installers and archives in Downloads.

The three PNGs have genuine alpha transparency around the application window, with transparent padding and rounded corners. The opaque interface pixels are copied from the real capture without resizing, text replacement or AI redrawing. The conversion script also verifies unchanged interior pixels after decoding the saved PNG.

Regenerate from window captures using `scripts/make-transparent-screenshot.swift`. Raw captures are kept locally in `dist/screenshots-source/` and are not included in the repository.

`overview.png` is the earlier, non-transparent legacy overview; current documentation uses the three PNGs above.

No personal documents or credentials are shown.
