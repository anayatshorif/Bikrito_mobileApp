# Bikrito — Build Plan (working notes)

> TEMPORARY file. Delete when the project is finished.
> Update the checkboxes as each part is completed.

## The idea

A simple offline mobile app for small online sellers and salesmen.
Seller creates an account with his business name, adds products and prices,
picks items when he sells, then taps **Print** — the bill opens in WhatsApp
ready to send to the buyer. All sales reports stay on the phone.
No internet needed for daily work, no server. Cloud backup comes later as a
paid upgrade. Bangla + English. Free to use; Pro plan gets backup, no app name
on bills, and extra features.

**Hard rule:** the seller must tap Send inside WhatsApp himself. WhatsApp does
not allow free apps to send messages automatically. So the app only opens
WhatsApp with the bill pre-filled — never sends.

## Theme (already established, keep it)

- White + red. Primary `#D83B3B`, ink `#252525`, muted `#858585`, canvas `#FAF9F7`
- Soft grey borders `#ECEAE7` / `#EFEDEB`, tint `#FFEEEE`, radius 14–23
- Bilingual through `String Function(String en, String bn) t`
- Keep it plain and practical. No gradients, no glassy/AI-looking decoration.

## Current file map

- `lib/main.dart` — app shell (2151 lines): `BikritoApp`, `LoginScreen`,
  `SetupScreen`, `HomeScreen`, `ProductFormScreen`, `_StartupErrorScreen`,
  `_FieldLabel`, `_OverviewMetric`, `_StatTile`, `_ProductImage`, `_money`,
  `_homePaymentLabel`
- `lib/bills/whatsapp_bill.dart` — `normaliseBdPhone`, `paymentLabel` (shared
  helpers)
- `lib/bills/invoice_widget.dart` — `BikritoInvoice` (invoice layout)
- `lib/bills/invoice_actions.dart` — `showInvoicePreview` (PNG capture, save,
  WhatsApp share)
- `lib/screens/products_screen.dart` — `ProductsScreen`
- `lib/screens/sales_screen.dart` — `SalesScreen`, `SalesReportsScreen`, `_SaleDetails`
- `lib/widgets/bikrito_bottom_navigation.dart` — `BikritoBottomBar`, `BikritoSaleButton`
- `lib/widgets/bikrito_logo.dart` — `BikritoLogo`
- `assets/logo.png` — app + receipt logo
- `lib/models/` — `shop_profile.dart`, `shop_product.dart`, `sale_record.dart`
- `lib/database/bikrito_database.dart` — schema v4 (profile, products, sales, sale_items)
- `database/schema.sql` — schema documentation

## Status: what is built

- [x] Shop account: owner name, shop name, WhatsApp number (+ email, user ID, 4-digit PIN)
- [x] Login with user ID + sha256-hashed PIN
- [x] Add product: name, price, optional photo (gallery; file on mobile, base64 on web)
- [x] Product list + delete
- [x] New sale: pick products, +/- quantity, fixed taka discount, payment method
      (cash / bKash / Nagad / bank / remaining)
- [x] Sale saved to SQLite with per-item rows
- [x] Sales reports list + per-sale detail sheet
- [x] Home dashboard: today, all-time, remaining, counts, recent sales
- [x] Offline-first, no server
- [x] Bangla + English toggle
- [x] White/red theme, bottom nav, center Sale button

## Status: what is missing (core of the idea)

- [x] **WhatsApp bill.** `url_launcher`, `wa.me` link, bill text builder, and
      Send buttons on the new-sale flow and sale details sheet.
- [x] Buyer name + WhatsApp number on a sale (added `buyer_name`, `buyer_phone`)
- [x] Bill number / bill layout (bill number derived from the sale `id`)
- [ ] Pro plan gating: free tier shows "Bikrito" footer on the bill,
      Pro removes it. No plan screen, no billing.
- [ ] Cloud backup (deferred by design)
- [ ] Settings screen

## Work order

### Part 1 — WhatsApp bill flow (start here)
1. Add `url_launcher` to `pubspec.yaml`.
2. Sale screen: add buyer name + buyer WhatsApp number fields.
3. Build the bill text from shop profile + items + subtotal + discount + total
   + payment method + footer line.
4. After saving a sale, show a "Send bill on WhatsApp" action.
5. Open `https://wa.me/<number>?text=<encoded bill>` with `launchUrl`
   (`LaunchMode.externalApplication`). Empty number allowed → WhatsApp asks
   which contact to send to.
6. Free tier footer: `Bill by Bikrito` (Bangla equivalent when in Bangla).
   Keep this behind a single flag so Pro can turn it off later.

Decision: buyer number is typed on the sale screen (no saved-customers list
for now). Normalise BD numbers to `8801XXXXXXXXX` — strip non-digits, drop a
leading `0`, prepend `880` when it starts with `1` and is 10 digits.

### Part 2 — Resend bill
- Add "Send bill on WhatsApp" to the `_SaleDetails` sheet in Reports.

### Part 3 — Plan screen
- Settings/plan screen with Free vs Pro, footer gating, placeholder for upgrade.
- No payment gateway. Just the toggle + copy.

### Part 4 — Backup (later)
- Export/import the SQLite file or JSON. Paid upgrade.

## Data model changes needed (Part 1)

`sales` table gains:
- `buyer_name TEXT NOT NULL DEFAULT ''`
- `buyer_phone TEXT NOT NULL DEFAULT ''`
- `bill_no INTEGER` (or derive from `id`)

Requires a schema version bump to 5 with an `onUpgrade` migration adding the
columns, plus updates to `database/schema.sql`, `SaleRecord`, `createSale`,
and `getSales`.

## Notes / gotchas
- Web builds cannot open `wa.me` the same way; guard with `kIsWeb` and fall
  back to copying the bill text to the clipboard.
- `launchUrl` needs no Android manifest changes for `https` links.
- Keep Bangla strings accurate; money is shown with `৳`.

## Progress log
- Session 1: full codebase read, status audit done, plan written. No code
  changes yet.
- Session 2: implemented the WhatsApp bill flow (Part 1) and resend from the
  sale details sheet (Part 2). Added `url_launcher`, buyer name/phone fields,
  schema v5 migration, bill builder, and `wa.me` opening with a web clipboard
  fallback.
- Session 3: added the app logo (`assets/logo.png`) to login, setup, home, and
  drawer headers, plus a downloadable PDF receipt with shop logo, shop info,
  sale number, and sale details (via `pdf` + `printing`).
- Session 4: replaced the PDF receipt with an image invoice (`BikritoInvoice` +
  PNG capture) that can be shared on WhatsApp or saved to the device. Added a
  shop logo upload to the setup screen (schema v6, `logo_path`/`logo_data`),
  and the invoice uses the shop logo with a "Bill by Bikrito" footer.
