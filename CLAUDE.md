# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project shape

MadeByHands is a handmade-goods marketplace. One repo holds **two deployables**:

1. **Flutter client** (`lib/`, `pubspec.yaml`) — Android, iOS, and web.
2. **Vercel Node serverless API** (`api/` + `server/`, `package.json`) — CommonJS `module.exports = async (req, res) => {}` handlers. Its dependencies (`razorpay`, `firebase-admin`) are tracked in `package.json`, entirely separate from pubspec.

Firestore is the shared database. The client reads it directly; anything financial is written only by the API through the Firebase Admin SDK.

## Commands

```sh
flutter pub get
flutter analyze
flutter test
flutter test test/platform_fee_calculator_test.dart            # single file
flutter test --plain-name "applies flat and percentage fees"   # single test
flutter run
flutter run -t lib/features/buyer/buyer_preview.dart           # buyer UI, no Firebase
firebase deploy --only firestore:rules
```

Web/production build (what Vercel runs via `vercel-build.sh`):

```sh
flutter build web --release --no-tree-shake-icons --dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID
```

Toolchain notes:

- On Windows, `flutter analyze` and `flutter run` need Developer Mode enabled (plugin builds require symlink support) or they abort with "Building with plugins requires symlink support".
- `flutter analyze` runs an implicit pub step that may rewrite `analysis_options.yaml` (adding an `analyzer.exclude` block) and `pubspec.lock`. Check `git status` afterwards and revert if you did not intend those changes.
- `lib/firebase_options.dart`, `android/app/google-services.json`, and the iOS/macOS plist equivalents are **gitignored**. A fresh clone will not compile until `flutterfire configure` is run against Firebase project `madebyhands-77f87`.
- `extract.ps1`, `extract_schema.ps1`, `generate_launcher_icons.ps1` and the `*_extracted.txt` files are one-off PowerShell helpers with hardcoded absolute paths. They are not part of any build.
- Android `applicationId` is `shop.madebyhands.app` (iOS bundle ID still `com.example.madebyhands`, pending).

## Client architecture

### Routing lives in `main.dart`

There is no route table or router package. `lib/main.dart` renders a `BlocConsumer<AuthBloc, AuthState>` and switches on the sealed auth state, then on `UserEntity.isAdminOrManager` / `isCreator` to pick the root widget: `AdminDashboardPage`, `CreatorFlowWrapper`, or `BuyerDashboardPage` (suspended users get a blocking screen). On sign-out the listener pops pushed routes and dispatches `BuyerSessionEnded` / `CreatorSessionEnded` so the lazy-singleton blocs drop the previous user's data. Navigation inside each panel is `Navigator.push` plus a nav index. Changing top-level entry conditions means editing `main.dart`.

Roles: `buyer`, `creator` (`seller` is tolerated as an alias), `manager`, `super_admin`. Legacy `admin` counts as a manager unless the email is on the hardcoded super-admin allowlist (kept in sync between `UserEntity.presetSuperAdminEmails` and `firestore.rules`). Managers run operations; finance, platform fees and roles are super-admin only.

### Two repository conventions coexist — match the feature you are in

- **`auth`, `creator`, `admin`** — full clean-architecture stack: `domain/repositories/` interface, `data/datasources/` (Firestore/Storage calls), `data/repositories/` impl. Returns `Either<Failure, T>` (fpdart).
- **`buyer`, `support`** — a single `data/firestore_*_repository.dart` implements the domain interface directly, with no datasource layer. Returns bare `Stream`/`Future` and **throws** on error instead of returning `Failure`.
- **`orders`** holds only shared domain code: `OrderStatus` (status normalisation) and the fee calculator. Orders are read by each panel's own repository.

There are no use cases; blocs call repositories directly.

`CreatorBloc` holds only the creator's profile session plus the outcome of the latest write (`CreatorAction` + `actionId`), so a product or order write never replaces the dashboard. Lists (products, orders, notifications) are streamed straight from `CreatorRepository.watch*` by the views; each widget keeps its own stream in `State` (Firestore streams are broadcast without replay, so never share one stream between two `StreamBuilder`s).

### Dependency injection

`get_it` via `serviceLocator` in `lib/init_dependencies.dart`, with a `_initX()` function per feature. Blocs are lazy singletons; auth/creator/admin datasources and repositories are factories, while buyer/support repositories and `OrderActionsApi` are lazy singletons. Every bloc is provided globally in `main.dart`'s `MultiBlocProvider`, so feature widgets assume they are already in scope.

`AdminCubit` and `BuyerCubit` are both just `Cubit<int>` holding a bottom-nav index — not domain state. `BuyerCubit` is created by the buyer dashboard itself, not registered in `get_it`.

Product categories live in `lib/core/constants/product_categories.dart` (`kProductCategories`, `productMatchesCategory`). Admins manage the `categories` collection; buyers and creators fall back to the constant list.

### Presentation layout

`presentation/pages/` are full screens, `presentation/views/` are tab bodies hosted inside a dashboard shell, `presentation/widgets/` are shared components.

Styling: light theme only (`AppTheme.lightThemeMode`). Take colors from `AppColors` in `lib/core/theme/app_theme.dart` (cream / sage / terracotta) rather than literals; fonts are Playfair Display + Montserrat via `google_fonts`. `flutter_screenutil` is initialized with `designSize: Size(360, 690)`, so sizes use `.sp`/`.h`/`.w`.

Buyer screens have their own look, taken from the Home tab (the cream of its arched panel as the page colour, ivory cards with thin gold outlines, deep-maroon heavy Montserrat headings, gold-outlined pill fields, maroon pill buttons): `BuyerTheme` / `BuyerColors` in `lib/features/buyer/presentation/theme/buyer_theme.dart`. The Home backdrop (grainy pink field, scalloped cream arch) is drawn in code by `ArchBackdrop` in `widgets/arch_backdrop.dart`; the other dashboard tabs are wrapped in `BuyerTabFrame`, which puts a strip of the same pink with a scalloped edge (`ScallopedHeader`) behind the status bar. `BuyerBackground` applies that theme along with the page colour, so wrap every buyer page in it and style through the theme (`Card`, `FilledButton`, `AppBar`, `TextField`, … need no per-widget colours); use `BuyerHeading` / `BuyerPageHeader` for headings. A page that opens dialogs or sheets from its `State` context must keep that state *below* `BuyerBackground` (see `CheckoutPage` → `_CheckoutBody`), or they fall back to the app theme. The Home tab itself is deliberately left on the app theme inside the dashboard. `SupportCenterPage` is shared with creators and takes the buyer look through a `pageWrapper`.

Cart contents and quantities are **buyer UI state backed by SharedPreferences**, never Firestore. Checkout re-sends the whole cart to the API.

## Payment flow

This is the most intricate path in the codebase and spans Dart, Node, and Firestore rules. Entry point: `lib/features/buyer/presentation/pages/checkout_page.dart` driving `lib/core/services/razorpay_service.dart`.

1. **Create order** — client POSTs `/api/create-order` with a Firebase ID token and cart lines of `{productId, quantity, customizations}`. **The client never sends prices.**
2. **Server prices the cart** — `server/checkout.js` `priceCart()` re-reads each product from Firestore, rejects inactive/out-of-stock products and unknown customization options (free-text customizations are accepted up to 200 chars), and computes unit prices. `api/create-order.js` then adds a flat fee per *distinct creator* (`server/fees.js`), creates the Razorpay order, and writes `paymentIntents/{razorpayOrderId}` with the priced snapshot. Shared handler plumbing (CORS, credentials, body parsing) is in `server/http.js`; Firebase Admin and ID-token verification in `server/auth.js`.
3. **Checkout UI** — on web, `RazorpayService` calls `window.openMadeByHandsRazorpay` (defined in `web/razorpay_checkout.js`, loaded from `web/index.html`) through the conditional import `razorpay_checkout_stub.dart` / `razorpay_checkout_web.dart`. On Android/iOS it uses the `razorpay_flutter` SDK.
4. **Finalize** — client POSTs `/api/finalize-payment`. The server verifies the HMAC-SHA256 signature with `crypto.timingSafeEqual`, re-fetches the order and payment from Razorpay's REST API (`server/razorpay.js`), and confirms status `captured`, matching amounts, and `notes.buyer_id == uid`. Then, in one Firestore transaction: decrement product stock, write **one `orders/{orderId}` document per creator** (all sharing `checkoutId`), mark the intent `paid`, and `create` `paymentReceipts/{paymentId}`. Creator/buyer notifications are a best-effort batch afterwards.
5. **Failure after capture** — the handler refunds through Razorpay and returns HTTP 409 with `refunded: true`, which the client surfaces as a distinct error. If finalize cannot be reached after a captured payment, the checkout page keeps the payment and offers "Retry order confirmation".
6. **Rejection** — creators and admins call `/api/reject-order` (`OrderActionsApi`). In a transaction it restores stock and `orderCount` and marks the order `Rejected`/`payoutStatus: cancelled`, then refunds `buyerPayableAmount`. A failed refund leaves `refundStatus: 'failed'`; calling the endpoint again retries the refund (admin "Retry refund").

Key invariants:

- **The idempotency key is `paymentReceipts/{paymentId}`.** A retry finds the existing receipt and returns the original `orderIds`. `RazorpayService.finalizePaidOrder` retries once on network timeouts, so finalize must stay idempotent.
- New endpoints call `applyCors(req, res)` from `server/http.js` (driven by `PAYMENT_ALLOWED_ORIGINS`).

## Money and status conventions

- **All Firestore amounts are integer rupees.** Paise exist only at the Razorpay boundary (`× 100`).
- The buyer pays `subtotal + flatFee`. The percentage commission applies **only when `subtotal > commissionThreshold`** and is deducted from the creator's subtotal, so `creatorNetAmount` can never go negative.
- Rates come from `settings/platform_economics` (`flatFee`, `percentFee`, `commissionThreshold`), defaulting to 50, 5, and 999. All three are admin-editable from Admin → Settings.
- This fee math is **duplicated**: `PlatformFeeCalculator` in `lib/features/orders/domain/entities/marketplace_order.dart` (covered by `test/platform_fee_calculator_test.dart`) and `computeOrderFees` in `server/fees.js` (covered by `npm test`). Change both together.
- Fees are snapshotted onto each order (`flatFee`, `commissionRate`, `commissionAmount`, `platformFee`, `creatorNetAmount`); Admin Finance derives balances from those stored values, so never recompute historical orders.
- **Order status strings are mixed-case in the database** — the API writes `'Placed'`, and older records use `'Accepted'`, `'pending'`, `'Completed'`. Always compare through `OrderStatus.normalize()` / `.label()` / `.shipmentStep()` in `lib/features/orders/domain/order_status.dart` instead of raw string equality.

## Security model (`firestore.rules`)

The rules are load-bearing, not advisory — deploy them alongside API changes.

- `paymentIntents` and `paymentReceipts` are `allow read, write: if false` — Admin SDK only.
- Clients can never create orders. **Any feature that produces a real order must go through the API**, not a client Firestore write.
- Creators may update orders only via a key whitelist (`status`, `updatedAt`, `consignmentNumber`, `carrierName`, `deliveredAt`) and only to forward fulfilment statuses (`Confirmed` … `Delivered`). Rejection goes through the API. Payout/payment/refund fields are super-admin only. Adding a creator-editable order field requires a rules change.
- Users may self-update only `name`, `phone`, `email`, `updatedAt`; only super admins change roles.
- Products: only verified creators create them, always `Pending Approval` + inactive; creator edits go back to review; creators may toggle `isActive` (approved listings only) and `stock` directly.
- `admin_logs` is the admin activity log: append-only, created only by the acting admin/manager (`actorUid == auth.uid`), readable only by super admins. New admin actions that change data should call `AdminLogRepository.log` (AdminBloc does for its events; views that write directly do it themselves). Logging is best-effort and must never block the action.
- `creator_verifications` (documents) and `creator_bank_accounts` (payout details) are private to the owner and admins / super admins.
- Product ownership is checked against **either** `creatorUid` **or** `creatorId`; both spellings exist in the data, and `server/checkout.js` falls back the same way.
- Storage rules are in `storage.rules` (`firebase deploy --only storage`). Uploads go to `creator_profiles/{uid}/…` and `products/{uid}/…`. The web build loads these images with `Image.network`, which needs CORS on the bucket: apply `storage-cors.json` once with `gcloud storage buckets update gs://madebyhands-77f87.firebasestorage.app --cors-file=storage-cors.json` (or `gsutil cors set storage-cors.json gs://madebyhands-77f87.firebasestorage.app`). Without it every Storage image is blank on web (Android/iOS are unaffected).

## Environment variables

Server (Vercel): `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `PAYMENT_ALLOWED_ORIGINS`. The service account must belong to project `madebyhands-77f87`, and allowed origins must include the deployed web origin, or ID-token verification and CORS will fail in confusing ways.

Client (`--dart-define`): `PAYMENT_API_BASE_URL` (required for Android/iOS; web falls back to its own origin) and `GOOGLE_CLIENT_ID` (web Google Sign-In). The Razorpay secret never reaches the client — the public key id is returned by `/api/create-order`.

Use Razorpay **test** credentials until checkout and verification have been exercised end to end.

## Tests

`test/` holds twelve Flutter test files and does not initialize Firebase. Widget tests inject `MockBuyerRepository` (`lib/features/buyer/data/mock_buyer_repository.dart`) and call `SharedPreferences.setMockInitialValues({})` in `setUp`. Keep new tests off live Firebase by depending on repository interfaces.

`test/api/` holds Node tests for the payment API (`npm test`) using a fake Firestore and stubbed Razorpay/auth; they need no network or credentials.

## Docs conventions

- `docs/firestore-schema.md` — shared collection/field contract across panels.
- `docs/buyer-firestore-schema.md` — buyer-facing contract.
- `docs/daily-log.md` — dated sections per workday recording per-role ownership and integration notes. The team convention is to append a new dated section rather than edit history; the file currently contains some duplicated sections from branch merges.
