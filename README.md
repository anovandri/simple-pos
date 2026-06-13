# Simple Bluetooth POS

Minimal Flutter point-of-sale app for Android with Bluetooth thermal printer support.

## What this app does

- Lists already-paired Bluetooth printers
- Connects/disconnects a selected printer
- Lets you save products locally on-device (name, price)
- Lets you pick saved products and quantity to add to cart quickly
- Stores each successful printed transaction locally for sync
- Provides a Sync button to draft transaction report email from unsynced transactions
- Prints a logo image at the top of receipt
- Prints store name + address and transaction date/time on receipt header
- Prints WiFi name/password under the thank-you section
- Supports 58mm and 80mm paper-width formatting
- Prints a receipt to the connected thermal printer

## Tech stack

- Flutter
- [`print_bluetooth_thermal`](https://pub.dev/packages/print_bluetooth_thermal) + [`esc_pos_utils_plus`](https://pub.dev/packages/esc_pos_utils_plus)

## Quick setup

1. Make sure Flutter SDK is installed.
2. In this folder, create platform folders (if not already present):
   - `flutter create .`
3. Install dependencies:
   - `flutter pub get`
4. Pair your thermal printer from Android Bluetooth settings first.
5. Run on Android device:
   - `flutter run`

## Android permissions

Ensure these are available in `android/app/src/main/AndroidManifest.xml`:

- `android.permission.BLUETOOTH`
- `android.permission.BLUETOOTH_ADMIN`
- `android.permission.BLUETOOTH_CONNECT` (Android 12+)
- `android.permission.BLUETOOTH_SCAN` (Android 12+)
- `android.permission.ACCESS_FINE_LOCATION` (older Android BLE discovery compatibility)

Some devices also need runtime permission prompts accepted manually.

## How to use

1. Open app and tap **Refresh Printers**.
2. Select paired printer.
3. Tap **Connect**.
4. Choose paper width and set store header/address and optional WiFi info.
5. Save products in the local catalog.
6. Select a saved product and quantity, then tap **Add to Cart**.
7. Tap **Preview & Print**.
8. Review the receipt preview, then tap **Print Now**.
9. Use **Sync** in the top bar to generate an email draft for unsynced transactions.

## Notes / limitations

- This implementation targets common thermal printers using ESC/POS over Bluetooth classic.
- iOS Bluetooth printing support depends on printer profile and plugin capabilities; Android is the primary target.
- Printer must be paired in system settings before it appears in app.
- Replace `assets/images/store_logo.png` with your own logo image if needed.

## Included test & preview

- Unit test: `test/receipt_builder_test.dart`
- Receipt preview runner: `tool/receipt_preview.dart`
