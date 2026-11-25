# Bikrito

Bikrito is an offline-first Flutter app for small shops and online sellers. Shop profiles, products, sales, and sale reports are stored locally in SQLite.

## Features

- English and Bangla setup and login
- Shop owner profile with a four-digit PIN
- Local product catalog with optional photos
- Sales with quantities, fixed taka discounts, and cash, bKash, Nagad, bank, or remaining payment methods
- COD orders with repeat-customer autofill and one-tap courier detail copying
- Local sales reports with itemized sale details and editable saved sales
- Android, Windows, and web builds

## Run on Android

Connect an Android device with USB debugging enabled, then run:

```sh
flutter pub get
flutter run -d <device-id>
```

Press `r` in the running terminal to hot reload Dart changes. Android native changes require a full restart.

## Local data

The SQLite database is created in the app's local storage. The schema is documented in [`database/schema.sql`](database/schema.sql). Web builds use browser-local IndexedDB via SQLite WebAssembly.
