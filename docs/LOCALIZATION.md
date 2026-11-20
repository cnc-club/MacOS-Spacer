# Localization

Spacer ships with English (`en`, the default) and Russian (`ru`). The in-app language choice is saved in the `appLanguage` preference. App-owned strings, sizes, suggestions and status messages use the same language; macOS dialogs follow the operating system.

To add a language:

1. Copy `Sources/Spacer/Resources/en.lproj/Localizable.strings` into a new `<language>.lproj` folder.
2. Translate values; keep all English keys identical. Preserve the count and order of `%@` placeholders and escape quotes and newlines.
3. Add the language code to the supported list in `Localization.swift`, and add a language-menu item in `App.swift` using its native language name.
4. Add the code to `CFBundleLocalizations` in `build-app.sh`. Swift Package Manager discovers the resource folder automatically.
5. Run `python3 scripts/check-localizations.py`, `./check.sh`, and `./build-app.sh debug`.
6. Check the actual app in both languages, including permission hints, confirmation dialogs, suggestions, long paths and narrow windows.

Use `T("English text", value)` for formatted strings. Use `LocalizedMessage` for stateful messages so switching languages also updates messages that are already visible. Filenames, filesystem paths and operating-system error descriptions are not translation keys.

Resources are copied into the app's Resources folder by `build-app.sh`; the executable loads packaged resources before falling back to Swift Package Manager's development bundle. Keep that bundle when distributing the app.
