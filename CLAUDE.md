# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

PrestaMesta's mobile app, being migrated incrementally from a UI-only demo (hardcoded fictional
data, matching the mockup at [prestamesta.fun](https://www.prestamesta.fun/)) into a real client
of [PrestaMesta_Server](https://github.com/PrestaMesta/PrestaMesta_Server). This is a phased,
checkpoint-based migration — see `docs/mobile-api-gaps.md` for exactly what the backend does and
doesn't support yet (MFA, identity verification, disbursement destination, payment history are all
documented as **not implemented on the server**, not bugs to fix here).

As of the current checkpoint: client authentication, the credit catalog + a local non-authoritative
estimate, the real loan request (`POST /prestamos/solicitar`, guarantor optional), the client's own
loans (`GET /client/prestamos` list + `GET /client/prestamos/:id` detail, both client-only), and now
`HomeScreen`/`StatusScreen`/`CalendarScreen`/`ProfileScreen` are all wired end-to-end through
`lib/features/{auth,credits,loans}/` + `lib/app/` (router, Riverpod providers) — **there is no
`DemoData` anywhere in the app anymore**; `lib/data/demo_data.dart` and `lib/widgets/demo_banner.dart`
were deleted entirely once their last real consumers (the four screens above) were rewritten to use
only real session/server data. `HomeScreen`/`StatusScreen` are backed by the server's own
`GET /client/prestamos*` responses — **the server is the source of truth**, not a locally cached
copy of the last `POST /prestamos/solicitar` response (see the "Home, Status, Calendar, Profile"
section below for the full `loansListControllerProvider`/`loanDetailControllerProvider` story).
This integration reflects the backend's *current* contract but is deliberately not a complete
production flow — the backend has no MFA, step-up, idempotency, identity verification, or
disbursement destination, and there are still no payments/amortization endpoints at all; see
`docs/mobile-api-gaps.md`. Don't assume a screen talks to the network just because `lib/core/`/a
sibling feature does — `CalendarScreen` in particular still makes zero network calls, by design,
because payments genuinely don't exist on the server yet (unlike the loan list/detail, which now
do).

`PrestaMesta_Server` and `PrestaMesta_Web` are sibling repos at `../PrestaMesta_Server` and
`../PrestaMesta_Web` — read-only reference for this repo; never edit them from here.

**This app is not release-ready** — `applicationId`/`namespace` are still the Flutter template
default (`com.example.prestamesta_app`), and release builds are still signed with the debug key
(confirmed in Checkpoint 6 via `apksigner verify`). See `docs/release-checklist.md` for the full
list of what's pending before a real release (signing, domains, manual device testing, version
policy) — don't treat any example value in that file as an approved decision.

## Commands

```bash
flutter pub get               # install dependencies
flutter analyze               # lint (config: analysis_options.yaml -> flutter_lints) — must be 100% clean, zero errors/warnings/infos (true as of Checkpoint 6)
dart format --set-exit-if-changed lib test   # formatting check
flutter test                  # run the whole suite
flutter test test/core/config/env_config_test.dart   # run a single test file
```

The app **requires** `--dart-define=APP_ENV=<local|testing|production>` and
`--dart-define=API_BASE_URL=<url>` to start at all (`lib/core/config/env_config.dart` validates
this in `main()` before `runApp`) — a bare `flutter run` shows a config-error screen instead of
launching. `env/local.json`/`env/testing.json` hold these per-environment (run with
`flutter run --dart-define-from-file=env/testing.json`) so nobody has to retype both flags by
hand — `env/production.json` deliberately doesn't exist yet (no real production domain, see
`docs/release-checklist.md`); never fabricate one "just so the file exists". See the README's
"Configuración de entornos" section for exact commands, including the `10.0.2.2` address needed to
reach a local backend from the Android emulator. `API_BASE_URL` is always just the server's origin
— `core/network/api_client.dart` appends `/api/v1` exactly once when building the `Dio` client
(every real `PrestaMesta_Server` route is mounted under that prefix); never bake `/api/v1` into an
`env/*.json` file or a `--dart-define` value, and never repeat it inside a repository's own call
path.

There is no CI config yet. Only the `android/` platform folder is present (no `ios/`, `web/`,
`linux/`, etc. scaffolding) — generate other platforms with `flutter create .` if ever needed.

## Architecture

**There is no hardcoded/fictional data anywhere in `lib/` — and none should ever be reintroduced.**
`lib/data/demo_data.dart` and `lib/widgets/demo_banner.dart` existed early in this migration as the
single seam for a not-yet-connected backend; once every screen that used them
(`HomeScreen`/`CalendarScreen`/`StatusScreen`/`ProfileScreen`, following `SimulationScreen`'s
earlier switch) had a real, honest replacement, both files were deleted rather than kept around as
an unused "demo mode" — there was no concrete, documented need for one. If a screen has nothing
real to show (no endpoint exists yet, a session-scoped value hasn't been set, a request failed),
it must show an honest empty/explanatory state (see `lib/widgets/empty_state.dart`) — never a
plausible-looking fabricated number, never a `DemoData`-style fallback "just so something renders".
`test/app/real_screens_test.dart`'s "no DemoData-only symbols leak into the real flow" test and
`test/screens/simulation_screen_test.dart`'s "no DemoData" test are what would catch a regression
here; a genuinely new demo/presentation mode would need its own explicit user approval, gated on
`APP_ENV=local` only, with its own visible disclaimer banner and provider state kept fully separate
from the real one — not a revival of the deleted files.

Navigation is `go_router` (`lib/app/router.dart`), routes: `/splash`, `/login`, `/register`, and a
`StatefulShellRoute.indexedStack` mounted at `/app/*` with five branches (`/app/inicio`,
`/app/simulacion`, `/app/calendario`, `/app/estado`, `/app/perfil`) — this replaced the old
hand-rolled `IndexedStack`+`_index` state that used to live in `RootShell`, but keeps the same
"switching tabs doesn't lose state" behavior (each branch is its own kept-alive `Navigator`).
- `RootShell` (`lib/screens/root_shell.dart`) is now the `builder` for that shell route: it takes a
  `StatefulNavigationShell` and renders the same `Scaffold` + `AppBar` (`PmLogo`) + `PmBottomNav` as
  before, calling `navigationShell.goBranch(index)` on tab tap instead of `setState`.
- **All guard logic goes through pure functions**: `authRedirect(AuthStatus, String location)` and
  `loanFlowRedirect({location, hasDraft, submissionStatus})` in `router.dart`, checked in that
  order (auth first, always) inside the single `redirect` callback. Don't add ad-hoc
  `context.go`/`Navigator` calls elsewhere to route around session/draft state; change these
  functions and let go_router's `redirect` + `refreshListenable` (a plain `ChangeNotifier` that
  `ref.listen`s `authControllerProvider`/`loanDraftControllerProvider`/
  `loanSubmissionControllerProvider` and just pings — every actual decision is a fresh `ref.read`
  inside `redirect`, never carried on the notifier itself) pick it up. Both are tested in isolation
  in `test/app/router_redirect_test.dart` — every state × location combination, no widget pump
  needed. `/app/simulacion/solicitud` (review) requires a non-null `LoanDraft`;
  `/app/simulacion/confirmacion` requires `LoanSubmissionStatus.success` — both nested under the
  `simulacion` `StatefulShellBranch`, not separate top-level routes. `/app/estado/:id`
  (`LoanDetailScreen`) is likewise nested under the `estado` branch — it needs no redirect guard
  (unlike the two above, it doesn't depend on in-memory draft/submission state, only on the numeric
  `:id` path segment, which the screen itself validates).
- The five tab screens themselves (`HomeScreen`, `SimulationScreen`, `CalendarScreen`,
  `StatusScreen`, `ProfileScreen`) are unchanged by the router migration, except `ProfileScreen`
  which now also wires the "Cerrar sesión" tile to `authControllerProvider.notifier.logout()`.

Theming is centralized in `lib/theme/app_theme.dart`:
- `AppColors` is the single source of truth for the brand palette (navy `#0C222F`, green gradient
  `#0E7C61` → `#1DA679`, etc.) — reference these constants rather than hardcoding hex colors in
  widgets/screens.
- `AppTheme.light()` builds the single `ThemeData` (Material 3, seeded `ColorScheme`, flat cards
  with 20px radius, flat transparent `AppBar`) consumed by `MaterialApp.theme` in `main.dart`.
  There is no dark theme defined.

Shared chrome lives in `lib/widgets/`: `pm_logo.dart` (wordmark), `pm_bottom_nav.dart` (bottom nav
bar), `empty_state.dart` (shared honest-empty-state shell, see the Home/Status/Calendar/Profile
section below). Both `pm_logo.dart` and `pm_bottom_nav.dart` are wrapped in a scale-down-only
`FittedBox` (Checkpoint 6) specifically so they never overflow at a large system text scale (up to
2.5x, tested in `test/widgets/pm_logo_test.dart`/`pm_bottom_nav_test.dart`) regardless of which
screen embeds them — at the default 1.0x scale this is a no-op, since `FittedBox(fit:
BoxFit.scaleDown)` only ever shrinks content that doesn't already fit, never grows it. If you add a
new shared chrome widget that gets reused across screens with varying available width (an AppBar
title, a Form header, ...), follow the same pattern rather than assuming a fixed width is safe.
`pm_bottom_nav.dart` additionally grows its own height moderately with the text scale (capped at
1.6x the base height) instead of staying rigid, and exposes tab selection to assistive technology
via `Semantics.selected` (not color alone) — the label text is never hidden or truncated at any
scale.

## Network/config/storage infrastructure (`lib/core/`)

- `core/config/env_config.dart`: `EnvConfig.fromDartDefines()` is the only source of the API base
  URL/environment — never hardcode a backend URL elsewhere. It throws `ConfigError` (never returns
  a half-valid config) if `APP_ENV`/`API_BASE_URL` are missing, invalid, or if `APP_ENV` is
  `testing` or `production` paired with a non-`https` URL — **only `local` may use plain HTTP**
  (the Android emulator's `10.0.2.2`).
- `core/network/api_client.dart`: the single `Dio` instance/factory. Deliberately has **no retry
  interceptor** — a financial or auth `POST` must never be replayed automatically by the HTTP
  layer; any future retry logic must be explicit and caller-scoped to safe (GET) requests only.
  Appends `/api/v1` to `EnvConfig.apiBaseUrl` exactly once here (stripping a trailing slash first)
  — every real route on `PrestaMesta_Server` is mounted under that prefix (confirmed in
  `PrestaMesta_Server/app.js`'s `app.use('/api/v1/...', ...)` calls and `openapi.yaml`'s `servers:
  url: /api/v1`), so `EnvConfig.apiBaseUrl`/`API_BASE_URL` must stay just the origin
  (`https://apitest.prestamesta.fun`, no path) — don't add `/api/v1` to a dart-define value or to
  an individual repository's call path, and don't move this prefix anywhere else. (This was a real
  bug until it was caught against a live deployed testing backend — before that, nothing in the
  test suite could have caught it, since every test uses a fake `HttpClientAdapter` that never
  validates a path against a real server.)
- `core/network/auth_interceptor.dart`: only attaches `Authorization: Bearer <token>` when a
  request sets `options.extra[requiresAuthExtraKey] = true` — public calls (login, register) must
  never set this. Also exposes `isSessionRejection(DioException)`, true only for a `401` whose
  server `codigo` is `TOKEN_EXPIRED`/`TOKEN_INVALID`; wiring that to actually clear the session and
  navigate to login is a `features/auth` concern, not this file's.
- `core/network/error_mapper.dart`: the only place that turns a `DioException` into an
  `AppException` — decides by the server's `codigo` field (see `ErrorEnvelope` in
  `PrestaMesta_Server/openapi.yaml`), never by parsing `mensaje` text. Screens/repositories must not
  branch on `DioException`/status codes directly.
- `core/network/logging_interceptor.dart`: logging gated on `logsEnabled` (constructor param,
  defaults to `kDebugMode` — accepted as a param specifically so the "disabled" branch is
  testable, since `kDebugMode` itself can't be flipped off under `flutter test`) that redacts
  `Authorization`/`Cookie`/`password`/`token`/`jwt`/`email`/`nombre`/`telefono` (case-insensitive,
  substring match, recurses into nested maps/lists) before printing. Add any new personal or
  financial field name here rather than assuming a field is safe to log by default.
- `core/storage/session_local_storage.dart`: stores the JWT and the minimal `ClienteSummary`
  (`{id, nombre, email}` — exactly what `POST /client/auth/login` returns) as **two separate**
  secure-storage entries, never one blob. There is no `GET /client/me`, so this profile is never
  refreshed from the server after login — don't add fields here the login response doesn't return.
- `core/utils/jwt_utils.dart`: `isJwtExpired()` reads the `exp` claim **without verifying the
  signature** — it's a local UX hint only (avoid keeping an obviously-dead token around), never an
  authorization decision. The server's 401 response remains the real authority.

All of the above have unit tests under `test/core/...` using hand-rolled fakes (no mockito/real
network/real secure storage) — follow that pattern rather than adding a mocking library.

## Authentication (`lib/features/auth/`, `lib/app/`)

- `data/auth_models.dart`: `RegisterRequest`/`LoginRequest`/`RegisterResult`/`LoginResult`, typed
  exactly to `ClienteRegistroInput`/`LoginInput` and the real `201`/`200` bodies in
  `openapi.yaml` — no untyped `Map<String, dynamic>` crossing repository/controller boundaries.
  `LoginResult.cliente` reuses `ClienteSummary` from `core/storage` (same shape, one model).
- `data/auth_repository.dart`: the only thing that calls `POST /client/auth/register|login`. Both
  calls are public (never set `requiresAuthExtraKey`) and both map every failure to `AppException`
  via `error_mapper.dart` — nothing above this layer touches `Dio`/`DioException` directly.
- `data/auth_validators.dart`: pure, local mirrors of the server's exact rules (`passwordProblems`
  matches `utils/passwordPolicy.js` byte-for-byte — 12–72 **UTF-8 bytes**, not
  `.length`/characters; `isNombreValid`/`isTelefonoValid` mirror `ClienteRegistroInput`'s
  maxLength/optional-ness). UX-only — the server is still the authority; don't invent stricter or
  looser rules than what's actually in `clienteAuthValidators.js`.
- `presentation/auth_state.dart` + `auth_controller.dart`: **one** `StateNotifier<AuthState>`
  (`authControllerProvider`) is the single source of truth for session status —
  `restoring/unauthenticated/authenticating/authenticated/error`, never separate booleans.
  - Restoration (`_restore()`, run once from the constructor) is **local-only by design**: reads
    the stored token/`ClienteSummary`, clears and goes `unauthenticated` if either is missing or
    `core/utils/jwt_utils.dart#isJwtExpired` says the token looks dead — there is no `GET
    /client/me` to actually revalidate against the server. A network failure during any later
    request must never be treated as "session invalid" here.
  - `sessionRejectedByServer()` is the *only* other thing that clears an authenticated session
    outside explicit `logout()`. It's what `app/providers.dart` wires as `ApiClient`'s
    `onSessionRejected` callback, so a real `401 TOKEN_EXPIRED`/`TOKEN_INVALID` anywhere in the app
    ends the session. It's guarded with a synchronous boolean flag (set *before* the first
    `await`) specifically so concurrent 401s from multiple in-flight requests don't race and clear
    storage twice — see `test/features/auth/presentation/auth_controller_test.dart`'s idempotency
    test if you touch this method.
  - `login()`/registration's `RegisterController.submit()` both no-op if already
    submitting/authenticating — that's the actual double-submit guard; the UI disabling the button
    is defense in depth, not the only protection.
- `presentation/register_controller.dart`: deliberately a **separate** `StateNotifier`
  (`idle/submitting/success/error`), not another `AuthState` branch — registration never touches
  the session (no token in the `201` response), so conflating the two would let a stray
  registration attempt affect login state. Uses `.autoDispose` since register-screen state has no
  reason to survive after leaving that screen.
- `app/providers.dart` ↔ `presentation/auth_controller.dart` have a **deliberate circular import**
  (`providers.dart` needs `authControllerProvider` for `ApiClient`'s `onSessionRejected` callback;
  `auth_controller.dart` needs `authRepositoryProvider`/`sessionLocalStorageProvider` from
  `providers.dart`). This is valid Dart (no part-of involved) and is the standard shape for "the
  network layer needs to call back into session state" — don't try to break the cycle by
  duplicating providers or introducing a global singleton instead.
- Every `Provider<T>`/`StateNotifierProvider<A, S>` in `providers.dart`/`auth_controller.dart` has
  an **explicit variable-level type annotation** (`final Provider<ApiClient> apiClientProvider =
  Provider<ApiClient>(...)`, not just `final apiClientProvider = ...`). Without it, `flutter
  analyze` reports a `top_level_cycle` error across these mutually-referencing providers — this
  isn't a style choice, removing the annotation breaks the build.
- Widget/router tests (`test/app/app_flow_test.dart`) drive the **real** `PrestaMestaApp`/router/
  `authControllerProvider`, overriding only `authRepositoryProvider` (a real `AuthRepository` wired
  to a hand-rolled `HttpClientAdapter` fake, `test/support/fake_http_client_adapter.dart`) and
  `sessionLocalStorageProvider` (in-memory `SecureStorage` fake) via `ProviderScope(overrides:
  [...])`. This is the pattern to extend for future features (credits, loans) rather than testing
  screens in isolation with hand-built widget trees.

## Credit catalog and estimate (`lib/features/credits/`)

- `data/credit_model.dart`: `Credito`, typed exactly to the real `GET /prestamos/creditos` response
  confirmed against `repositories/prestamoRepository.js` (`SELECT * FROM creditos`, raw `mysql2`
  rows) — `monto_minimo`/`monto_maximo`/`tasa_interes_anual` arrive as **decimal strings**
  (`"1000.00"`), not numbers, because `mysql2` serializes `DECIMAL` columns as strings by default;
  `Credito.fromJson` rejects (never coerces) a response where they aren't strings.
- **Never use `double` for money, rates, or terms anywhere in this feature.** `Credito`'s decimal
  fields and everything in `loan_estimate.dart` are `Decimal` (package `decimal`) or `Rational`
  (package `rational`, for intermediate arithmetic like `tasaAnual/100 * plazoMeses/12` that isn't
  guaranteed to terminate in decimal). `double` appears exactly once, at the very end of
  `core/utils/currency_formatter.dart`, purely to hand a value to `intl`'s `NumberFormat` for
  display — never for a computation. If you add a new money-shaped field, follow this pattern, not
  `double`/`num`.
- `data/loan_estimate.dart#calculateEstimate`: a **pure, local, non-authoritative** mirror of
  `PrestaMesta_Server/utils/money.js#calcularMontoTotalAPagar` — same formula (simple annual
  interest, prorated by term, no compounding), same rounding (`ROUND_HALF_UP` to 2 decimals,
  reimplemented by hand on exact `Rational` comparisons — not trusting `Decimal.round()`'s own mode
  without verifying it first). Test vectors in
  `test/features/credits/data/loan_estimate_test.dart` are copied from
  `PrestaMesta_Server/tests/unit/money.test.js`, including a hand-constructed exact-tie case (`1 @
  1% for 6 months` → `1.005` exactly) specifically to catch an accidental switch to
  round-half-to-even. **This never becomes the authoritative amount** — that only happens
  server-side, inside `POST /prestamos/solicitar`, which does not exist in this app yet. Don't wire
  this estimate into anything that looks like a submission.
- `data/amount_input_parser.dart#parseUserAmount`: rejects (returns `null`, never coerces to zero)
  anything not an unambiguous non-negative amount with ≤2 decimals — no thousands separators, no
  mixing `.`/`,`, no scientific notation. `null` must always be treated as "invalid input", never as
  a zero amount.
- `data/credits_repository.dart#fetchCreditos`: the first real **authenticated** endpoint in this
  app (`GET /prestamos/creditos`, `verificarTokenClienteOAdmin` server-side — accepts client or
  admin tokens, requires *a* session, not specifically a client one). Marks the request with
  `requiresAuthExtraKey` from `core/network/auth_interceptor.dart` — never builds the `Authorization`
  header itself. Requests as `Dio<dynamic>`, not `Dio<List<dynamic>>`, specifically so a
  wrong-shaped body (e.g. an object instead of the documented array) is caught by this repository's
  own `is! List` check as a controlled `respuestaInvalida`, instead of Dio's generic-type
  enforcement surfacing it as an opaque `DioException` that `error_mapper.dart` would otherwise
  misclassify as `sinConexion`.
- `presentation/credits_controller.dart`: `CreditsController` has its own explicit statuses
  (`initialLoading/data/initialError/refreshing/refreshError`) — "empty catalog" is deliberately
  *not* one of them (it's `data` with an empty list, fully derivable, see `CreditsState.isEmpty`).
  `creditsControllerProvider` does `ref.watch(authControllerProvider.select((s) => s.cliente?.id))`
  — this is what makes the catalog load only with a session, and get recreated (fresh, empty state)
  whenever the authenticated client id changes (login, logout, or a different client logging in),
  so one session's catalog can never leak into the next. Loading is auto-triggered once from the
  provider's `create` callback; `loadInitial()` itself is idempotent per instance (a second call is
  a no-op), while `retry()`/`refresh()` are freely re-triggerable — whichever one was *started*
  last wins via an internal sequence counter, regardless of response arrival order (see the
  "later-started request wins" test in `credits_controller_test.dart`). This class reuses the same
  401 wiring as auth (`core/network/auth_interceptor.dart` → `AuthController.sessionRejectedByServer`
  via `app/providers.dart`) — a `TOKEN_EXPIRED`/`TOKEN_INVALID` while fetching credits ends the
  session and the router redirects to `/login` exactly like anywhere else in the app; a 403, a
  timeout, or a 500 never do.
- `presentation/widgets/credits_catalog_view.dart` is the single place that switches on
  `CreditsStatus` for the UI — `SimulationScreen` itself doesn't. `SimulationScreen` is only
  responsible for the amount-entry/estimate section on top of that.

### A non-obvious `flutter test` gotcha you will hit again in this feature

`testWidgets()` runs inside Flutter's `FakeAsync`-based test zone, where `Future.delayed`/`Timer`
only fire when you pump. A real `Dio` request — even through the hand-rolled
`FakeHttpClientAdapter` in `test/support/`, which resolves synchronously — still creates at least
one `Timer` internally in `DioMixin.fetch`. Two different fixes apply depending on *how* the
request was triggered, and using the wrong one hangs the test forever with no error:
- **Awaited directly from test code** (e.g. `await controller.loadInitial()` called by the test
  itself, not via a widget interaction): wrap it in `await tester.runAsync(() =>
  controller.loadInitial())`. This temporarily escapes the fake zone so the real timer can fire.
- **Triggered by a widget interaction** (e.g. `tester.tap(find.text('Reintentar'))`, whose
  `onPressed` fires the async call without the test awaiting it directly): do **not** use
  `runAsync` here — plain `await tester.tap(...); await tester.pumpAndSettle();` is correct,
  because `pumpAndSettle` already knows how to advance the fake clock and fire pending timers
  itself; wrapping it in `runAsync` breaks that instead of helping.
See `test/screens/simulation_screen_test.dart` for both patterns side by side.

## Loan request (`lib/features/loans/`)

- `data/guarantor.dart`: `Guarantor` (`nombre`, `telefono`, optional `direccion`/`ingresoMensual`).
  `toJson()` omits `direccion`/`ingreso_mensual` entirely (not `null`) when unset, matching the
  "don't send empty optional fields" rule for this endpoint; `ingresoMensual` converts
  `Decimal -> double` only at this JSON boundary (see the money rule below).
- `data/loan_request.dart`: `LoanRequest` (`creditoId`, `montoSolicitado` as `Decimal`, optional
  `aval`). `toJson()` sends **exactly** `credito_id`/`monto_solicitado`(+`aval` when present) —
  never `cliente_id`, `administrador_id`, `monto_total_a_pagar`, `saldo_pendiente`, `estado`,
  `fecha_solicitud`, `tasa_interes_anual`, or `plazo_meses`. Those are all server-computed/
  server-authoritative; if you're ever tempted to add one of them to this model to "help" the
  server, don't — re-read `docs/mobile-api-gaps.md` and the confirmed contract first.
- `data/loan_submission_response.dart`: `LoanSubmissionResponse.fromJson` is strict, not lenient —
  every field must be present with the exact confirmed type or it throws `FormatException`
  (surfaced by the repository as a generic "unexpected response" `AppException`, never silently
  defaulted). Notably `montoSolicitado` arrives as a JSON **number** but `montoTotalAPagar` arrives
  as a **string** — this asymmetry is real (confirmed against the server), not a bug to
  "normalize" away. `EstadoPrestamo.parse` rejects any value other than the three known statuses
  the same way — an unrecognized `estado` is a hard error, not a fallback to "pendiente".
- `data/loan_validators.dart`: pure UX-only mirrors of the server's guarantor field rules
  (`isGuarantorTelefonoValid` requires 7–20 chars — unlike the client's own phone, the guarantor's
  is not optional once the guarantor section is enabled). Same "UX hint, not the authority" caveat
  as `auth_validators.dart`.
- `data/loans_repository.dart`: the **only** thing that calls `POST /prestamos/solicitar` — one
  `_dio.post` call, no retry logic anywhere in this file or above it. Unlike `GET
  /prestamos/creditos` (dual-domain, `verificarTokenClienteOAdmin`), this route is
  **client-only** server-side (`verificarTokenCliente`, confirmed against
  `PrestaMesta_Server/routes/prestamoRoutes.js` and `middleware/authMiddleware.js`) — a
  structurally valid admin-audience JWT is rejected purely on audience mismatch with `401
  TOKEN_INVALID` (confirmed in `utils/jwt.js#verifyClienteToken`), never `403 FORBIDDEN` and never
  a "credenciales incorrectas"-style message. This app never has to special-case that: it already
  routes every `TOKEN_INVALID`/`TOKEN_EXPIRED` through the same generic session-rejection path
  (`core/network/auth_interceptor.dart` → `AuthController.sessionRejectedByServer`) that
  `error_mapper.dart` already gives a generic "tu sesión no es válida" message for any 401 without
  a recognized envelope — see the "admin-audience token" tests in `loans_repository_test.dart`/
  `loan_flow_test.dart`. There is also no code path that could send `cliente_id` from a decoded
  token claim or the request body — `LoanRequest` has no such field at all (see its doc comment);
  the server derives the client identity itself, from the verified token's `sub`, never from
  anything in the JSON body. Splits failures into three
  buckets: a decoded `LoanSubmissionResponse` (success), an `AppException` via the shared
  `error_mapper.dart` (a *definite* failure — the server responded, or the failure type proves the
  request never left the client), or `LoanSubmissionAmbiguousException` (the outcome is genuinely
  unknown). `_isAmbiguousFailure` is the single place that decision is made, based on
  `DioExceptionType` semantics — read the doc comment on that function before touching it; it's
  deliberately conservative (defaults to "ambiguous" whenever a `DioExceptionType` doesn't *prove*
  no request bytes ever reached the server — this includes `cancel`, since Dio's cancellation
  carries no information about how much of the request had already been transmitted), matching the
  checkpoint's "when uncertain, assume ambiguous" requirement.
- `presentation/loan_draft.dart`: `LoanDraft` (the selected `Credito` + validated amount + optional
  `Guarantor`) is held **in memory only** — no `flutter_secure_storage`, no disk, no logs — by
  `LoanDraftController` (`null` = "no draft", the only state every guard/screen checks).
  `loanDraftControllerProvider` is recreated (fresh `null`) whenever the authenticated client id
  changes, the same session-keying pattern as `creditsControllerProvider` — this is what makes a
  draft disappear on logout or on a different client logging in, with no explicit "clear on
  logout" call needed anywhere else.
- `presentation/loan_submission_state.dart` + `loan_submission_controller.dart`:
  `LoanSubmissionStatus` is `idle/submitting/success/failure/outcomeUnknown` — five explicit states,
  never booleans layered on top of each other. `LoanSubmissionController.submit()`:
  - No-ops (doesn't re-POST) if already `submitting`, already `success`, or permanently blocked
    after an `outcomeUnknown` — see the double/triple-submit and ambiguous-outcome tests in
    `loan_submission_controller_test.dart`.
  - On `LoanSubmissionAmbiguousException`, sets a `bool` flag that blocks this controller instance
    from ever submitting again — there is no "unblock"/reset method by design. The backend has no
    idempotency key, so the only safe path forward is a deliberately fresh attempt (new draft, new
    review, and in practice a new controller once the client-id-keyed provider above recreates it),
    never an automatic or one-tap retry of the same request. Confirmed at the provider level (not
    just the bare class) in
    `test/features/loans/presentation/loan_submission_block_reset_test.dart`: logout + a fresh
    login lands on a brand new, `idle` controller for the (re-)authenticated client id — the block
    is lifted by the same client-id-keyed recreation as the draft/loans list (see
    `loansListControllerProvider` below), never by a dedicated reset call.
  - Guards every `state = ...` assignment with `if (!mounted) return;` — a `TOKEN_EXPIRED`/
    `TOKEN_INVALID` on the in-flight submission can concurrently dispose this same
    client-id-keyed controller (via `sessionRejectedByServer`) before the `await` above it
    resolves; without the guard this throws "used after dispose". If you add a new `state = ...`
    line here, it needs the same guard.
- `presentation/loan_review_screen.dart`/`loan_confirmation_screen.dart`: the review screen shows
  the **local, non-authoritative** estimate (same `calculateEstimate` as the credits feature) with
  an explicit "estimate, not final" disclaimer; the confirmation screen shows **only** fields that
  came back on `LoanSubmissionResponse` — it never recalculates or "corrects" the server's
  `montoTotalAPagar`, and always renders `EstadoPrestamo.pendiente` as "Pendiente de revisión",
  never "aprobado"/"activo"/"depositado" (the server hasn't actually approved anything yet at this
  point in the flow). Dates are hand-formatted numerically rather than via `intl`'s
  `DateFormat('d MMM y', 'es_MX')`, to avoid a `LocaleDataException` without adding
  `initializeDateFormatting()` to `main.dart`. `estadoPrestamoLabel()`/`formatLoanDate()` (see
  `presentation/loan_status_label.dart`) are shared with `HomeScreen`/`StatusScreen` below — this is
  the single place that wording changes, so all three can never independently drift into showing
  `PENDIENTE` differently.
- `presentation/widgets/guarantor_form.dart`: the guarantor section is off by default; toggling it
  off clears its controllers and sends no `aval` data at all (`LoanRequest.toJson()` simply omits
  the key) — there's no "empty guarantor object" ever sent.
- Money: same rule as `features/credits` — `Decimal` end to end, `double` only at the exact JSON
  serialization boundary (`Guarantor.toJson`/`LoanRequest.toJson`), verified lossless for the
  amounts this endpoint actually accepts. Never introduce `double` for anything computed.
- Routing/guards for this feature live in `router.dart`'s `loanFlowRedirect` (see the Architecture
  section above) — don't add screen-level `if (draft == null) context.go(...)` checks as a
  substitute for the route guard.

## Home, Status, Calendar, Profile (`lib/screens/`)

Home and Estado are backed by the client's real loans on the server
(`GET /client/prestamos`/`GET /client/prestamos/:id`) — **the server is the single source of
truth**. There is no session-only local cache of "the last thing the POST returned" anymore (the
old `SessionLoanSummaryController` was deleted once these two real endpoints existed): a loan
submitted successfully is only ever shown after the app re-fetches the list from the server, and
nothing about it survives only in memory — a fresh `GET` on the next app run (or the next login)
shows the same data the server has, not "whatever this session happened to submit."

- `data/pagination.dart`: `Pagination` (`page`, `limit`, `total`, `totalPages`) — the exact
  envelope both `GET /client/prestamos` and `GET /admin/prestamos` return (`totalPages` is `0`
  only when `total` is `0`, confirmed against `services/prestamoService.js#construirPaginacion`).
- `data/credito_resumen.dart`: `CreditoResumen` (`id`, `nombre`) — the minimal credit view nested
  inside a loan list/detail row. Deliberately **not** the full `Credito` catalog model
  (`features/credits/data/credit_model.dart`): the loans endpoints never return
  `monto_minimo`/`monto_maximo`/`tasa_interes_anual`/`plazo_meses`, so this app must not pretend it
  has them here.
- `data/loan_list_item.dart`: `PrestamoListItem` (`id`, `credito: CreditoResumen`,
  `montoSolicitado`/`montoTotalAPagar`/`saldoPendiente` as `Decimal`, `estado: EstadoPrestamo`
  reused from `loan_submission_response.dart`, `fechaSolicitud`, nullable `fechaDecision`) — one row
  of the list. Also holds `LoanListPage` (`data: List<PrestamoListItem>` + `pagination:
  Pagination`), the full body of `GET /client/prestamos`. `monto_solicitado`/`monto_total_a_pagar`/
  `saldo_pendiente` arrive as **decimal strings** here (`mysql2`-read `DECIMAL` columns) — unlike
  `POST /prestamos/solicitar`'s response, where `montoSolicitado` is a JSON number (an echo of the
  request body). This asymmetry between the two endpoints is real, confirmed against the server,
  and deliberately not normalized away in either model.
- `data/aval_detalle.dart`: `AvalDetalle` (`id`, `nombre`, `telefono`, nullable
  `direccion`/`ingresoMensual`, the latter a `Decimal`) — only ever nested inside a loan detail.
  `null` fields mean the value was genuinely never captured (never coerced to `''`/`0`).
- `data/loan_detail.dart`: `PrestamoDetalle` — composed over a `PrestamoListItem` (`resumen`) plus
  an optional `aval: AvalDetalle?`, with getters (`id`, `credito`, `montoSolicitado`, ...)
  delegating to `resumen` so callers don't need to know about the composition. `aval == null` means
  the loan genuinely has no guarantor on record (the server's `LEFT JOIN` found no row) — never an
  empty/zero-filled `AvalDetalle` standing in for "none". The full body of
  `GET /client/prestamos/:id`.
- `data/loans_repository.dart` (same file as `submit()`, see the Loan request section above) also
  has `fetchLoans({page, limit})` (`GET /client/prestamos`, marks `requiresAuthExtraKey` like every
  other authenticated call) and `fetchLoanById(id)` (`GET /client/prestamos/:id`). Both are
  **client-only** server-side (`verificarTokenCliente`, confirmed against
  `routes/clientePrestamoRoutes.js`) — same audience rule as `submit()`. A `404 LOAN_NOT_FOUND` from
  `fetchLoanById` already maps to `AppExceptionType.noEncontrado` via the shared
  `error_mapper.dart` — this app never tries to distinguish "doesn't exist" from "belongs to
  another client" itself, since the server deliberately returns the exact same 404 for both
  (anti-enumeration, same principle as login).
- `presentation/loans_list_state.dart` + `loans_list_controller.dart`: `LoansListState` has the
  same five explicit statuses as `CreditsState`
  (`initialLoading/data/initialError/refreshing/refreshError` — "empty" is `data` with an empty
  list, not its own status; see `LoansListState.isEmpty`). `loansListControllerProvider` is
  client-id-keyed exactly like `creditsControllerProvider`/`loanDraftControllerProvider`
  (`ref.watch(authControllerProvider.select((s) => s.cliente?.id))`), so **logout or a different
  client logging in recreates it fresh** (empty, not yet loaded) — this is what stops one client's
  loans from ever leaking into another session's view, with no separate "clear on logout" call
  needed anywhere. `LoansListController.loadInitial()` fires once per instance (idempotent, mirrors
  `CreditsController`); `refresh()` re-fetches whatever page is currently shown (the only way this
  app updates the list — no auto-polling, ever); `nextPage()`/`previousPage()` fetch the adjacent
  page (server-paginated, fixed `fecha_solicitud DESC, id DESC` order, so `loans.first` on page 1
  is always the most recent). **`refreshAfterSubmission()` is what satisfies "a successful
  submission refreshes the list"**: the provider's `create` callback does `ref.listen` on
  `loanSubmissionControllerProvider` and calls it only on a transition into
  `LoanSubmissionStatus.success` — always jumping back to page 1 regardless of which page was being
  viewed, so the just-created loan (sorted first by the server) is immediately visible. Like the
  old `SessionLoanSummaryController` this replaced, this depends on being **actively watched**
  (`ref.watch`, or `ProviderContainer.listen` in a test — not a one-off `read`) for its
  client-id-keyed recreation and its `ref.listen` registration to happen promptly; `HomeScreen`
  watching it early (same as before) is what guarantees that in practice.
- `presentation/loan_detail_state.dart` + `loan_detail_controller.dart`: `LoanDetailState` is
  `loading/data/error` — three explicit statuses, no booleans. `loanDetailControllerProvider` is a
  `StateNotifierProvider.autoDispose.family<..., int>` keyed **only** on the numeric loan id from
  the route (no client-id keying here — a loan's detail is fetched fresh every time its screen
  opens and disposed as soon as nothing watches it, so it never survives long enough to leak
  between sessions). `LoanDetailController` fetches once on construction; the presentation layer
  only ever calls `retry()`.
- `screens/home_screen.dart`: greets with the real `ClienteSummary.nombre` (never the client's
  `id` as a headline value), a CTA into Simulación, and the **most recent loan as reported by the
  server right now** — `loansListControllerProvider`'s `mostRecent` getter (`loans.first` on page
  1) — with a "Ver detalle" button into `/app/estado/:id`. The honest empty message is "Aún no has
  enviado una solicitud." — **never** "No tienes préstamos", which would overstate what the server
  actually confirms if the initial load itself fails. No balance, no next payment, no
  application-progress bar: none of that can be backed by any real endpoint.
- `screens/status_screen.dart`: lists the client's real loans via `LoansListView`
  (`features/loans/presentation/widgets/loans_list_view.dart`, same five-state-switch pattern as
  `CreditsCatalogView`) — a refresh button (`IconButton`, tooltip "Actualizar") and "Anterior"/
  "Siguiente" page controls (a `Wrap`, not a `Row`, so they drop to a second line instead of
  overflowing at a large text scale). Tapping a row navigates to `/app/estado/:id`. The empty state
  ("Aún no tienes solicitudes registradas.") includes a CTA back to Simulación. Never fabricates a
  review timeline, an analyst name, or a decision date — those don't exist on
  `PrestamoListItem`/`PrestamoDetalle` and must not be invented here either.
- `features/loans/presentation/loan_detail_screen.dart` (`/app/estado/:id`, nested under the
  `estado` `StatefulShellBranch` in `router.dart`): every server-authoritative field
  (`PrestamoDetalle`) plus the aval section — "Esta solicitud no tiene un aval registrado." when
  `aval == null`, otherwise nombre/teléfono/dirección/ingreso mensual. `loanId` is `null` only when
  the route's `:id` segment wasn't a valid positive integer (a malformed deep link); that case
  shows a static "Identificador de solicitud inválido." message and never calls the repository.
- `screens/calendar_screen.dart`: unconditionally `EmptyState` — the backend has payments/
  amortization implemented **nowhere at all** (not even partially, and unlike the loan list/detail,
  there is no endpoint here to integrate), so there's genuinely nothing this screen could show, not
  even an honest "no pending payments" (that would still require an endpoint that doesn't exist).
  This screen makes zero network calls; don't add one "just to check."
- `screens/profile_screen.dart`: only `ClienteSummary.{nombre, email}` — never `telefono` (login
  doesn't return it, see `core/storage/session_local_storage.dart`), never a fabricated
  role/score/verification-status field, never a toggle that implies a security feature (2FA/
  step-up) is active when it isn't. The one 2FA-related string on this screen is a static,
  non-interactive note that it's coming "cuando el servidor lo admita" — deliberately not a
  `Switch` or any other control that could be tapped. Keeps the same logout confirmation dialog as
  before (exact text "Cerrar sesión" on both the tile and the dialog's confirm button — several
  existing tests in `test/app/app_flow_test.dart`/`loan_flow_test.dart` depend on that exact
  string, so don't rename it without checking those first).
- Session behavior shared by every model/provider above: monetary fields are always `Decimal`,
  never `double` (same rule as `features/credits`/the rest of `features/loans`) — `double` never
  appears in this feature except at `currency_formatter.dart`'s exact JSON/display boundary. `401`
  (specifically `TOKEN_EXPIRED`/`TOKEN_INVALID`) on any of these requests ends the session through
  the same shared path as everywhere else in the app (`core/network/auth_interceptor.dart` →
  `AuthController.sessionRejectedByServer`, wired once in `app/providers.dart`) — nothing in this
  feature has its own 401 handling. A `403`, a timeout, or a `500` never end the session; they
  surface as an `initialError`/`refreshError`/`LoanDetailStatus.error` with the server's own
  message via `error_mapper.dart`, same as the credit catalog.
- `lib/widgets/empty_state.dart`: the one shared "nothing real to show" shell (icon + title +
  message + optional single action), used by `CalendarScreen` and `StatusScreen`'s
  no-loans/initial-error cases. Not a general-purpose design system — only extract a new shared
  widget here when a second/third real screen would otherwise duplicate the same layout, same
  reasoning as `estadoPrestamoLabel()`/`formatLoanDate()` in `loan_status_label.dart`.
- Cross-branch navigation from these screens (e.g. Home's "Ir a Simulación", Calendar's "Ir a
  Inicio") uses plain `context.go('/app/...')`, the same pattern already established in
  `loan_review_screen.dart`/`loan_confirmation_screen.dart` — this switches the
  `StatefulShellRoute` branch in place via go_router's own route matching, it does **not** push a
  second copy of `RootShell`/the `AppBar`/bottom nav. Don't thread `StatefulNavigationShell` down
  into these leaf screens to call `goBranch` instead — there's no `of(context)` accessor for it in
  the installed go_router version, and `context.go` is already the pattern the loans feature uses.

## Conventions worth preserving

- No hardcoded/fictional data anywhere in the real app flow — see the "no `DemoData`" rule in the
  Architecture section above. A screen with nothing real to show renders an honest empty/explanatory
  state instead.
- UI copy is in Spanish (matches prestamesta.fun); keep new user-facing strings in Spanish for
  consistency.
