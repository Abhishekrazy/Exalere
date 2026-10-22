# Exalere AI & Contributor Rules (AGENTS.md)

This file defines guidelines and architectural constraints for any AI coding agent (such as Google Antigravity, Gemini Code Assist, Cursor, Claude, Copilot) or human contributor working on the **Exalere** codebase.

---

## 🏛️ Project Architecture & Stack

- **Framework**: Flutter 3.13.2+ (Null-Safety)
- **Supported Targets**:
  - Android Mobile & Tablet
  - Android TV / Fire TV (Leanback / D-Pad driven)
  - Windows Desktop (64-bit)
- **State Management**: `Provider` (`ChangeNotifierProvider`, `Consumer`, `context.watch/read`)
- **Video Playback Engine**: `media_kit` + `media_kit_video` (libmpv), plus external player handoff (VLC / Just Player) via `url_launcher`
- **Data & APIs**:
  - Universal dynamic plugin architecture (`media_provider_plugin.dart`, `provider_registry.dart`, `exalere_plugin_adapter.dart`, `iptv_provider.dart`)
  - Local caching via `shared_preferences` and custom file caching

---

## 🚨 Critical Rules for Code Contributions

### 1. Android TV & D-Pad Compatibility
- **Never break TV navigation**: Every clickable, selectable, or interactive widget on TV-supported screens **MUST** be wrapped in `TvFocusable`. No bare `InkWell`, `ElevatedButton`, `TextButton`, `ListTile`, or `GestureDetector` as the root interactive widget on TV.
- Always support directional D-Pad keys (Up, Down, Left, Right, Select/Enter, Back) via `TvFocusable` + `TvSpatialNavigation`.
- Ensure focus order is logical and does not trap the user.
- **Horizontal shelves**: Every `ListView` with `scrollDirection: Axis.horizontal` containing focusable items MUST have `clipBehavior: Clip.none` AND `cacheExtent: 350.0`. The wrapping `SizedBox` height must be `≥ cardHeight + 20px` to prevent scale-animation clipping.
- **Dialogs**: Every dialog shown on TV must have exactly one `TvFocusable(autofocus: true)` on the primary/safe action button.
- **Competing row groups**: When a `Row` contains separate focusable groups (e.g., tabs + a far-right toggle), wrap each group in a `FocusTraversalGroup(policy: OrderedTraversalPolicy())` to prevent spatial nav from jumping to the wrong element.
- **Lazy ListView first card**: Expose a `firstCardFocusNode` parameter from every horizontal shelf widget so the parent screen can explicitly focus the first card on D-Pad Down from the row above.
- See full guardrail skill: [`.agents/skills/tv-dpad-navigation-guardian/SKILL.md`](.agents/skills/tv-dpad-navigation-guardian/SKILL.md)
- See quick-reference rule: [`.agents/rules/tv_dpad_navigation.md`](.agents/rules/tv_dpad_navigation.md)

### 2. State Management & Performance
- Keep state mutations inside appropriate `ChangeNotifier` classes (`AppProvider`, `LibraryProvider`, `CastProvider`).
- Avoid putting heavy synchronous parsing or decryption operations on the UI isolate. Utilize background isolates or microtasks where necessary.
- Clean up controllers, video listeners, and stream subscriptions in `dispose()`.

### 3. Video Playback & External Players
- Always handle stream loading states, timeouts, and player errors gracefully with user-friendly retry prompts.
- Ensure fallback to external players (VLC, MX Player) functions properly when hardware decoders fail.

### 4. Code Quality & Formatting
- **Zero Warnings**: Code must pass `flutter analyze` cleanly.
- Do not introduce arbitrary external dependencies without maintainer alignment.
- Adhere to effective Dart formatting standards (`flutter format .`).

### 5. Licensing & Non-Commercial Constraint
- All contributions are licensed under the **PolyForm Noncommercial License 1.0.0**.
- Do not include proprietary, closed-source, or commercial SDKs that contradict this license.

### 6. Zero Hardcoded Colors & Static Styling (Theme & Design Tokens)
- **Zero hardcoded colors in widgets**: NEVER use `Colors.black`, `Colors.white`, `Colors.amber`, `Color(0xFF...)`, or `Colors.white12/24/70` directly in UI widgets.
- **Always use theme tokens**:
  - Surfaces & Accents: `context.tokens.surfaceCard`, `context.tokens.surfaceElevated`, `context.tokens.primaryAccent`, `context.tokens.secondaryAccent`.
  - Text: `context.tokens.textPrimary`, `context.tokens.textSecondary`, `context.tokens.textMuted`, or `Theme.of(context).colorScheme.onPrimary` (on accent buttons).
  - Borders & Shadows: `context.tokens.borderSubtle`, `context.tokens.borderFocus`, `context.tokens.shadowColor`.
  - Gradients & Overlays: `context.tokens.scrimGradient`, `context.tokens.heroGradient`.
- **Pre-commit Audit**: Run `python scripts/detect_hardcoded_styles.py --path <modified_file>` before finalizing changes. Any hardcoded color violation will fail review.

### 7. Mandatory Code Formatting Before Commit
- **Format check**: Always format code using `dart format .` before staging and committing.
- Verify with `dart format --output=none --set-exit-if-changed .` to ensure exit code 0.
- CI will strictly reject any commits that contain unformatted Dart code.

### 8. Native Scraper Providers

Several sites resolve downloads through the same HubCloud tail. Do **not** write a
provider from scratch; extend the shared layer.

**Adding a site** (all four of the current scrapers are ~30 lines each):

1. Subclass `HubCloudSiteScraper` in `lib/services/scrapers/` and supply
   `domainKey`, `providerId`, `displayName`, `fallbackBaseUrl`, and — only if it
   differs — `searchPath` / `catalogPath`.
2. Override `parseListingHtml` **only** when the site's cards are not `a[title]`
   anchors (`MoviesDriveProvider` is the example: an anchor wrapping
   `.poster-card`). Otherwise the generic `HtmlGridParser` handles it.
3. Declare `supportsMetadata => false` in the registry adapter. Scrapers resolve a
   post page straight to a stream; claiming metadata makes the provider self-test
   show a red failure for a capability the provider never had.
4. Add forwarding `static` members for anything tests call — Dart does not inherit
   statics, so `SomeProvider.parseListing` must be declared on the subclass.
5. Register the built-in manifest in `PluginService.builtInEngineManifests` under a
   private scheme (`<id>://engine`), add a `CommunityPluginItem` store entry, and
   add a branch in `createPlugin` (`lib/plugins/plugins.dart`).

**Invariants that must not regress:**

- **Never register a scraper in `ProviderRegistry._registerDefaultProviders()`.**
  A fresh install must report no playable provider so Home shows library/favourite
  instead of play buttons. Scrapers are *installable*, not enabled by default.
  `test/hdhub4u_plugin_wiring_test.dart` pins this.
- **Never hardcode a site domain.** These sites rotate mirrors; resolve through
  `ProviderBaseUrlService` (`domainKey`) with the constant as fallback only.
- **Unsupported gates must be skipped, not faked.** Shortlink gates
  (`thenaukriadda`, `_wp_http`, DriveSeed, GDFlix) are not solved; detect them with
  `isShortlinkGated` and return no streams rather than a dead link.

**Verification:** unit tests cover parsers only. Live behaviour is confirmed with
the in-app provider self-test (Settings → Add-ons → flask icon), which reports
Catalog / Search / Metadata / Streams per provider.

### 9. WARP (Cloudflare over WireGuard)

The Network settings block offers WARP, AntiDPI and DNS-over-HTTPS. All three are
independent and composable: DoH fixes a poisoned hostname lookup, AntiDPI defeats
inspection of the TLS handshake, WARP tunnels everything.

**Transport is WireGuard, not MASQUE.** The reference app drives WARP through a
bundled `usque` MASQUE client, which is **GPL-3.0** and therefore cannot be
redistributed under this project's PolyForm Noncommercial licence. WireGuard is
served by `com.wireguard.android:tunnel` (Apache-2.0), so the licence constraint
decides the transport. Do not "restore parity" by adding the MASQUE binary.

**WARP ships in BOTH flavours.** Unlike the torrent engine (§7), a VPN client is a
declarable and permitted Play feature, so there is no policy reason to strip it
from the store build. If WARP is ever removed from `play`, the Play Console VPN
declaration and the `VpnService` manifest entry must be removed with it.

**Layering.** Dart owns registration (`warp_registration_client.dart`), persistence
and UI (`warp_service.dart`); Kotlin owns only the tunnel
(`WarpVpnService.kt` + `WarpChannel.kt`). Keep it that way — the Cloudflare
round-trip is testable in Dart, and only what genuinely needs the platform is
native.

**Invariants:**

- **Never report WARP as available before probing the platform.** `WarpService`
  starts `unavailable`; availability comes only from a successful channel probe.
- **Never persist "enabled" after a failed connect**, or the next launch tries to
  restore a tunnel that never came up.
- **Consent comes from the Activity.** `VpnService.prepare()` returns an Intent
  that only an Activity can launch, so the result returns via `onActivityResult`,
  not from the channel call. Do not block the channel waiting for it.
- **The notification is mandatory.** Android requires a foreground-service
  notification for as long as the tunnel is up; users will see it.