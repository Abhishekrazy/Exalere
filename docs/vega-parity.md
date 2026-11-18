# Vega parity — how the reference app is built, and what Exalere does differently

Status: **implemented** (2026-11-19). The four parity areas below — global search,
provider-driven Home, playback recovery and provider portability — are in the
codebase, covered by tests, and this file records what was copied, what was
rejected, and what is still unverified.

- Reference app (mobile): `vega-org/vega-app` **v5.3.2**
- Reference app (desktop, used for the mpv/search/home details):
  `vega-org/vega-desktop` (main, read 2026-11-19)
- Provider source: `Zenda-Cross/vega-providers` (69 provider modules)
- Artifact: `vega-v5.3.2.apk`, 79,244,309 bytes,
  SHA-256 `0a257a9392aceebcffd64a2c816b1109195388be272826f30b9ca438b251e65d`

## 1. What actually ships inside the reference APK

| Component | Observation | Why it matters to us |
|---|---|---|
| `assets/index.android.bundle` (7,140,044 B) | **Hermes bytecode** (magic `c6 1f bc 03`) | The JS logic cannot be read as text from the APK; the readable equivalent is the tagged source tree. Do not claim "decompiled JS" from this bundle. |
| `libavcodec/avformat/avfilter/avutil/swscale/swresample`, `libffmpegJNI`, `libffmpegkit` | Full FFmpeg stack | Used for remux/transcode (cast, downloads, format repair) — not for playback (playback is ExoPlayer on mobile, libmpv on desktop). |
| `libtorrent4j.so` (15.8 MB) | Bundled libtorrent | Torrent streaming is native, not a plugin. |
| `libusque.so` (13.6 MB), `libciadpi.so` | MASQUE tunnel + ByeDPI | Network bypass is shipped in-app. We use WireGuard + our own DoH/AntiDPI instead, for licence reasons (§9 of AGENTS.md). |
| `libjingle_peerconnection_so.so` (12.5 MB) | WebRTC | Cast/remote playback transport. |
| **No provider manifests or `urls.json` in the APK** | Only code references | Providers are **not** bundled. They are installed from a provider *source* (GitHub repo with `manifest.json` + per-provider JS). "Steal the providers from the app" is therefore impossible. |

## 2. Global search — every provider at once

**Vega** (`src/lib/hooks/useGlobalSearch.ts`, `src/pages/SearchPage.tsx`):

- One request per **installed** provider, started together, each with its own
  `{ isLoading, error }` entry. The loading list is seeded with every provider
  *before* any request runs, so the screen never pretends there is only one source.
- Results accumulate per provider (`SearchPageData[]`), rendered as **one
  `ContentSlider` per provider**. A provider that answered with nothing still gets
  a row; a failed provider keeps its error.
- An `AbortController` per query discards the previous query's answers.

**Exalere now** (`ProviderRegistry.searchAllProviders`,
`ProviderSearchSection`, `ActiveSearchScreen`):

- Same fan-out: `searchProviders` (stream-capable, search-capable) are queried
  concurrently, each with a 15 s timeout, and each answer is reported the moment it
  arrives. Statuses are `searching / loaded / empty / failed` — "no match" and
  "this provider failed" are different states on purpose.
- `AppProvider` keeps the slices and a merged list. The merged list is ordered by
  provider priority and deduplicated by normalised title; a provider filter chip
  (`ProviderSearchChip`) restricts the grid to one provider's slice.
- A generation counter replaces the abort controller: mpv/provider HTTP calls
  cannot be cancelled mid-flight in Dart, so a late answer for a replaced query is
  dropped instead of painted.
- In the merged view every card carries a small provider badge naming the provider
  that supplied it, so "where can I watch this" is answered on the card itself;
  selecting a provider chip switches to that provider's own slice (no badge, since
  the header already says it).
- TMDB discovery is appended as its own `TMDB` section only when **no** installed
  provider returned anything, and is gated in the background when the user asked
  for available titles only.

Deliberate difference: we keep the grid (and add chips) instead of a row per
provider. The existing grid already carries the TV D-pad focus graph, paging and
render budget; a second shelf-based results view would duplicate all of it for no
extra information. The chips carry the same information Vega's rows do.

## 3. Home — provider catalogues, not a hardcoded shelf list

**Vega** (`src/lib/getHomepagedata.ts`, `useHomePageData`, `HomePage.tsx`):

- The **active provider declares its catalogues**; `getCatalog()` returns
  `{title, filter}` rows and each row is fetched with `Promise.allSettled`. A
  failing row is returned with an `error` and rendered empty, never blanking the
  page.
- Hero posts are picked from the fetched rows; Continue Watching comes from local
  history and local content.

**Exalere now** (`MediaProviderPlugin.catalogs`, `ProviderCatalogRow`,
`ProviderHomeRowsService`, `HomeScreen`):

- Providers declare Home rows (`catalogs`) next to their capabilities. HDHub4u,
  MoviesDrive, MoviesMod, UHDMovies, Movies4U and RogMovies declare one "latest"
  row each; MovieBox declares movies + series; a remote addon's declared catalogs
  become rows too.
- `ProviderHomeRowsService` loads them with hard bounds (8 rows total, 2 per
  provider, 12 s each), concurrently within a provider and sequentially across
  providers, dropping only the row that failed or came back empty.
- Home renders provider rows above the editorial TMDB shelves (after Continue
  Watching) and hands the first row the focus node when nothing above it claims
  it. Rows pass through `ShelfPlanner`, so a title shown once is not repeated in
  the shelf below.
- `supportsCatalogFeeds` stays `false` for the scrapers: their listing is a
  latest-additions grid, not a category catalogue, and the provider self-test must
  keep reporting that. Declaring a Home row is a narrower claim.

## 4. Playback — what Vega does, what we now do

**Vega desktop** (`src/lib/hooks/useMpvPlayer.ts`) initialises libmpv with
`hwdec=auto-safe` + `vo=gpu-next` when the hardware-acceleration setting is on,
special-cases torrents (`cache-secs=120`, `demuxer-max-bytes=150MiB`,
`cache-pause-wait=5`, reconnect options), and proxies HLS through a local HTTP
proxy so headers and cookies survive segment requests. It does **not** retry
playback on a different decoder: an `end-file` error is surfaced as-is. The mobile
build plays through ExoPlayer, where decoder selection is ExoPlayer's job.

**Exalere now**:

- `PlaybackProfile` derives `vd-lavc-threads`, `vd-lavc-software-fallback`,
  `framedrop` and `video-sync` from the device class (TV / 32-bit / low RAM), while
  the user's `VideoDecoderMode` still owns `hwdec`. It never overrides that
  setting silently.
- `PlaybackFallbackPolicy` classifies player messages (decoder / network /
  container) and permits **exactly one** software retry, either on a
  decoder-classified error or when the new 22 s start watchdog sees no frames. The
  retry sets `hwdec=no` and reopens the same URL at the last position (live
  restarts at the live edge), with a one-time notice. After that the user gets a
  real error instead of an endless spinner.
- The existing cache/network map (`VideoCacheService`) is untouched: the two
  layers answer different questions (how much to buffer vs. how to decode).

This is the direct answer to "the TV hangs": a broken hardware decoder used to
produce no error at all (the old handler explicitly swallowed codec messages), so
nothing ever moved. Now it produces either a retry or an error.

## 5. Providers — what is portable, and what is not

The portable pattern is the one in AGENTS.md §8: extend `HubCloudSiteScraper`,
never write a site from scratch. Two new shared pieces were needed for the newer
mirrors:

- **Nexdrive hop** (`NexdriveExtractor`): a post page links to a `nexdrive` mirror
  page, which lists V-Cloud / V-Drive / G-Direct / Gofile. The mirror page is plain
  HTML, so following it is safe. A mirror that instead shows a timer/rotation step
  is treated as gated and yields no streams.
- **V-Cloud** (`HubCloudExtractor.decodeDoubleAtob`): these pages never put the
  file URL in an anchor; they base64-encode the signed URL twice and decode it in
  the browser. Reading that is a pure string operation (no cookies, no captcha) and
  the resulting page exposes a Cloudflare R2 link, which mpv streams directly
  (`R2 CDN` server, preferred first for streaming).

**Newly wired end to end:** `RogMoviesProvider` (`rogmovies`).

- Catalogue + search read the site's own Typesense proxy (`/ts-search.php?q=…`)
  with `TypesenseSearchParser` — no markup to break.
- Resolution goes post page → `nexdrive` → V-Cloud → decoded token page → R2 CDN.
  Confirmed live on 2026-11-19 (search JSON, post page, nexdrive page, V-Cloud
  double-atob, and the token page's `r2.dev` link).
- Registered as an installable built-in (`rogmovies://engine`), never on by
  default.

**Viability of the rest of the 69 Vega providers** (evidence: provider source,
site HTML probed on 2026-11-19; "unverified" means no live probe, not "works"):

| Family / example | Status | Reason |
|---|---|---|
| `hdhub4u`, `4khdhub`, `drive` (MoviesDrive), `movies4u`, `mod` (MoviesMod), `uhd` (UHDMovies) | already native | HubCloud tail, implemented before this change |
| `movieBox`/`movieBoxWeb`, `dramacool`, `vidsrc` | already native | dedicated engines |
| `luxMovies` (RogMovies) | **new in this change** | JSON search proxy + nexdrive/V-Cloud/R2 tail, verified |
| `zeefliz` | blocked | search + post page parse, but the tail is `nexdrive.store`, which serves a JS timer/rotation step instead of server links — a gate, so no streams are claimed |
| `gokuHD` | blocked | 403 (WAF) on the listing without a browser session |
| `eonMovies`, `extraflix`, `catmovies` | unverified | listings/streams are API- or JS-driven; no server-rendered download links observed |
| `topmovies` (`moviesleech`), `katmovies`, `joya9tv` | unverified | search/listing did not return cards in the served HTML during the probe |
| `anikoto`, `kickAssAnime`, `animesalt`, `animeworld`, `hianime`, `animetsu` | out of scope for now | anime engines with their own stream protocols; not a HubCloud tail |
| `netflixMirror`, `primeMirror`, `disneyMirror`, `showbox`, `mxplayer`, `kissKh`, `youtube`, `internetArchive` | out of scope | authenticated or dedicated APIs/DRM, not scrapable HTML |
| `torrentio`, `castle` | different transport | torrent/WebView API; the app already ships a torrent engine and a Stremio addon adapter |

Porting more sites is therefore a per-site decision with a real evidence test, not
a volume exercise. A provider that cannot resolve honestly stays unported.

## 6. Gaps that remain

| # | Gap | Severity | Notes |
|---|---|---|---|
| 1 | Duplicate video tracks can be listed | Low | Not de-duplicated by `width×height : bitrate`; the provider fix earlier removed the quality-label lie but not the duplicate tracks. |
| 2 | Provider capability failures are opaque | Medium | Self-test still reports a stage as failed without the HTTP status/blocked host; Kanban task 5. |
| 3 | Mobile overlay still has 16 "More" entries | Medium | Grouped TV doors are done; the mobile mapping is Kanban task 3. |
| 4 | No runtime TV capture of the new player fallback | Medium | The Windows build is blocked on this host (symlink support) and the emulator's player surface freezes after playback; the fallback is covered by unit tests, not by eye. |
| 5 | Vega's HLS local proxy not implemented | Low | Vega desktop proxies HLS to keep headers/cookies on segments. We pass headers to mpv directly and have not observed this failing; adding a proxy is a native surface we have not needed. |

## 7. Deliberate non-goals

- **FFmpeg remux stack / live transcoding**: we play with mpv, which reads the
  containers these providers serve. "Live encoding" in the sense of transcoding on
  the device would need the FFmpeg stack for a case we have not observed failing.
- **MASQUE (`usque`)**: GPL-3.0, incompatible with the project licence. We keep
  WireGuard.
- **Bundling providers**: violates the fresh-install invariant (no playable
  provider by default).
- **A JS provider sandbox like Vega's**: our providers are native Dart modules.
  A sandbox is a security surface plus an interpreter dependency; the current
  plugin manifest + native engine model covers the same installability without it.

## 8. Evidence

- `test/provider_global_search_test.dart` (10 tests): per-provider states, timeout
  isolation, cancellation, stale-generation discard, provider filtering, chips.
- `test/provider_home_rows_test.dart` (9 tests): row planning, failure isolation,
  caps, adult filtering, declared rows for the built-in scrapers.
- `test/playback_fallback_test.dart` (13 tests): failure classification, one-retry
  rule, live handling, device profiles.
- `test/rogmovies_provider_test.dart` (13 tests): V-Cloud double-atob, R2 parsing,
  nexdrive page parsing, post-page button labels, full resolve chain with mocked
  HTTP, installation wiring.
- `flutter analyze` clean; full suite **831 tests green** (2026-11-19).
- Live probes (PowerShell, 2026-11-19): `rogmovies.cyou/ts-search.php?q=inception`
  → 3 hits; post page → 3 `nexdrive.beer` buttons labelled 480p/720p/1080p; mirror
  page → `vcloud.my`; V-Cloud page decoded to a signed token URL; token page →
  `*.r2.dev` file link + PixelDrain + HubCloud proxy.
