# Player Controls Inventory & Grouping Plan

**Status:** proposal · **Scope:** `lib/ui/screens/player/**` + `lib/ui/screens/player_screen.dart` · **No source changes.**

**Method.** Written at `HEAD 49de9fc`, against the **current working tree** (three player files carry
uncommitted edits — `player_tv_controls.dart`, `player_controls_overlay.dart`,
`player_server_sheet.dart`; this plan describes them as they are now, not as on `main`, so line
numbers move if those edits are rebased). Every row below is traced to the widget/callback that builds
it. Paths are relative to the
repo root; `tv_controls` = `lib/ui/screens/player/player_tv_controls.dart`,
`overlay` = `lib/ui/screens/player/player_controls_overlay.dart`,
`video_view` = `lib/ui/screens/player/player_video_view.dart`.

## Headline findings

1. **The TV bar is the real problem: up to 11 pills in one horizontally-scrolling row** — there is no
   "TV More menu" in this codebase. `_buildTvActionButtons` (`tv_controls:701`) renders a
   `SingleChildScrollView(Axis.horizontal)` (`tv_controls:718-723`) and every optional feature is a
   sibling pill. On VOD series all 11 appear; on Live TV 10 (speed is hidden, play/pause is added) —
   plus the Restart pill on its own row above the seekbar (`tv_controls:395-449`).
2. **The mobile bar is small; the mobile *menu* is the problem** — `PlayerMoreOptionsMenu`
   (`overlay:876`) holds **16 rows**, several of which duplicate a control already on the bar
   (quality, servers, audio, fit, PiP).
3. **Leaves are duplicated across surfaces** — playback speed exists in three places: TV pill
   (`tv_controls:1017`), mobile More row (`overlay:1198`) and an accordion inside the Audio &
   Subtitles sheet (`audio_subtitles_sheet.dart:1154`). Night mode + gain exist twice: the Audio
   sheet's "AUDIO ENHANCEMENTS" (`audio_subtitles_sheet.dart:1122`) and `PlayerAudioTunerSheet`.
4. **Two surfaces are not D-pad-safe today** — the sleep-timer sheet is a non-scrollable `Column`
   (`player_sleep_timer_sheet.dart:114`) and the speed sheet a bare `Wrap`
   (`player_speed_dialog.dart:44`). They are the overflow risk at 720p / short landscape.
5. **Parity gaps (not invented, just absent):** mobile has **no Episodes picker** in the player
   overlay — `onOpenEpisodes` is only passed to `PlayerTvControls` (`video_view:518`); downloads and
   parental controls are **not player controls at all** (download starts from the details screen,
   `details_screen.dart:366-414`; parental lives in Settings/Profile), so they are out of scope for
   any player category.

## 1. Inventory — 35 controls

Family separator rows are marked with a leading **·** and bold text. "—" = not contextual.

| Control | Where it lives today | What it opens | How often | Contextual? |
|---|---|---|---|---|
| **· Transport & timeline** | | | | |
| Play / Pause | **Both** — TV pill on Live TV only (`tv_controls:726-797`); also Select/Enter on the focused seekbar (`tv_controls:481-487`); mobile centre CTA (`video_view:737-788`) and bottom-bar button (`overlay:590-628`) | nothing (toggles) | Frequent | TV pill Live-only; VOD uses seekbar Select |
| Seek bar / scrub | **Both** — TV seekbar (`tv_controls:451-632`), mobile slider (`overlay:701-751`) | nothing | Frequent | — |
| Relative seek −10 s / +30 s | **Both** — D-pad ←/→ with seekbar focused (`tv_controls:493-500`), ←/→ with controls hidden (`player_key_handler.dart:144-166`), mobile double-tap (`video_view:690`, `796`) | nothing | Frequent | VOD only (`player_key_handler.dart:145,157`) |
| Rewind 10 s button | **Mobile overlay** — centre quick row (`video_view:690-729`) | nothing | Frequent | VOD only (`video_view:687-689`) |
| Forward 30 s button | **Mobile overlay** — centre quick row (`video_view:796-835`) | nothing | Frequent | VOD only |
| Restart from beginning | **Both** — TV pill above the seekbar (`tv_controls:402-446`); mobile resume-banner button (`player_gesture_hud.dart:390`) | nothing | Occasional | TV: non-Live only (`tv_controls:211-215`); mobile: only when a resume position exists (`player_gesture_hud.dart:344`) |
| Skip Intro / Outro | **Both** — TV pill (`tv_controls:800-847`), mobile bottom bar (`overlay:768-807`), gesture HUD (`player_gesture_hud.dart:452`) | nothing (seeks) | Frequent | Only while a skip interval is active |
| **· Source** | | | | |
| Server / provider + stream | **Both** — TV "Source" pill (`tv_controls:965-1013`), mobile top-bar pill (`overlay:356-401`), mobile More → *Streaming Servers* (`overlay:1145-1159`) | `PlayerServerDialog`, two steps provider → stream (`player_server_sheet.dart:48-639`; step 1 `:313-476`, step 2 `:478-638`) | Occasional | Label collapses to `1080p` when one server (`tv_controls:105-118`, `overlay:72-85`); pill hidden when no quality and one server (`tv_controls:965`) |
| Video quality tier | **Both** — mobile More → *Video Quality* (`overlay:1126-1144`); on TV folded into the same Source pill because `onSelectQuality` wins over `onSelectServer` (`tv_controls:981`) | `PlayerQualityDialog` (`player_server_sheet.dart:642-1148`) | Occasional | Only with >1 selectable video track or >1 fallback quality (`player_server_sheet.dart:719-720`, `:1006-1025`) |
| **· Audio & subtitles** | | | | |
| "Audio & Subs" entry | **Both** — TV pill (`tv_controls:901-957`), mobile top-bar icon (`overlay:406-430`), mobile More → *Audio & Subtitles* (`overlay:1160-1178`) | `PlayerAudioSubtitlesSheet` — full-screen route (`player_audio_subtitles_sheet.dart:77-139`); 2 tabs on phones (`:603-633`), 2 columns on wide/TV (`:431-433`, `:543-601`) | Frequent | — |
| Audio track / dubbed track | Inside that sheet — "AUDIO TRACKS" (`player_audio_subtitles_sheet.dart:1025`), "DUBBED TRACKS" (`:1076`) | nothing | Occasional | >1 audio track |
| Subtitle track (embedded + online) | Inside that sheet — "EMBEDDED SUBTITLES" (`:1758`) + "ONLINE SUBTITLES" (`:1803`) | nothing; also fetches online subs | Occasional | Tracks available |
| Audio sync delay | Inside that sheet — "AUDIO SYNC DELAY" (`:1139`, control `:1207`) | nothing | Rare | — |
| Subtitle sync delay | Inside that sheet — "SUBTITLE SYNC DELAY" (`:1849`, control `:1307`) | nothing | Rare | — |
| Subtitle appearance & styling | Inside that sheet — "SUBTITLE APPEARANCE & STYLING" (`:1864`) | nothing | Rare | — |
| Audio enhancements (night mode + gain) | Inside that sheet — "AUDIO ENHANCEMENTS" (`:1122`, content `:790`) | nothing | Occasional | Duplicates the EQ tuner (below) |
| Audio EQ / pre-amp | **Both** — TV "Audio EQ" pill (`tv_controls:1316-1365`), mobile More → *Audio Equalizer & Clarity* (`overlay:1032-1051`) | `PlayerAudioTunerSheet` — 5 presets + 100-200 % boost (`player_audio_tuner_sheet.dart:11-54`, `:244-512`) | Rare | — |
| Playback speed | **Both** — TV pill VOD only (`tv_controls:1017-1066`), mobile More (`overlay:1198-1212`), sheet accordion (`player_audio_subtitles_sheet.dart:1154`) | `PlayerSpeedSheet` 0.5×–2× (`player_speed_dialog.dart:8-106`) | Occasional | Hidden on Live TV (`tv_controls:1017`) |
| Audio-only mode | **Both** — TV "Audio-Only" pill (`tv_controls:1368-1417`), mobile More → *Audio-Only Mode (Low Power)* (`overlay:1052-1071`) | nothing (toggles `isAudioOnly`, `player_audio_mixin.dart:66-72`) | Rare | — |
| **· Video & picture** | | | | |
| Fit / Cover (aspect) | **Both** — TV pill (`tv_controls:1069-1127`), mobile bottom bar (`overlay:811-837`), mobile More → *Fit Screen / Aspect Ratio* (`overlay:1179-1197`) | nothing (toggles `videoFit`) | Occasional | — |
| Picture tuner | **Both** — TV "Picture" pill (`tv_controls:1264-1313`), mobile More → *Picture Tuner (Display)* (`overlay:1016-1031`) | `PlayerPictureTunerSheet` — 5 presets + brightness/contrast/saturation/gamma (`player_picture_tuner_sheet.dart:11-33`, `:294-464`); dialog on TV, bottom sheet on phone (`:69-112`) | Rare | — |
| Stats for Nerds | **Both** — TV "Stats" pill (`tv_controls:1202-1261`), mobile More → *Stats for Nerds* (`overlay:1314-1345`) | floating `PlayerStatsOverlay` HUD (`video_view:932-945`) with its own close (`player_stats_overlay.dart:141-143`) | Rare | — |
| **· Session, output & device** | | | | |
| Episodes picker | **TV bar only** — contextual pill (`tv_controls:849-898` → `player_screen.dart:1229-1250`) | `PlayerEpisodesSheet` (`player_screen.dart:1240`) | Occasional | Series only. **No mobile entry today** (`video_view:518`) |
| Next episode | **Mobile More menu** — *Next Episode* (`overlay:1249-1272`); also the floating countdown card play-now / dismiss (`player_next_episode_card.dart:194,230`; wired `video_view:919-929`) | plays next / cancels countdown | Occasional | Series with a next episode |
| Sleep timer | **Both** — TV pill with live remaining badge (`tv_controls:1130-1199`), mobile top-bar icon (`overlay:481-524`), mobile More (`overlay:1092-1125`) | `PlayerSleepTimerSheet` — 5 presets + end-of-media (`player_sleep_timer_sheet.dart:9-325`, presets `:68-80`), wired `video_view:206-229` | Occasional | — |
| Watch party (LAN sync) | **Both** — TV "Party" pill (`tv_controls:1420-1469`), mobile More (`overlay:1072-1091`) | `WatchPartyDialog` (`player_screen.dart:918-928`) | Rare | — |
| Cast | **Mobile overlay + More** — top-bar cast icon, non-TV only (`overlay:431-479`), More row (`overlay:1213-1228`), cast session card (`overlay:1460-1587`) | `CastDialog` (`overlay:442`, `video_view:642`) | Occasional | `!isTv` (`overlay:431`) |
| Picture-in-Picture | **Mobile overlay + More** — bottom bar Android only (`overlay:838-865`), More row (`overlay:1229-1248`) | enters PiP (`player_screen.dart:1374`) | Occasional | `Platform.isAndroid` (`overlay:838`, `:1229`) |
| Open in external player | **Mobile More menu** (`overlay:1273-1291`) | external intent (`player_screen.dart:1284`, `:1373`) | Rare | — |
| Fullscreen toggle | **Mobile More menu**, desktop only (`overlay:1292-1313`) | `_toggleFullscreen` (`player_screen.dart:1375`) | Rare | Windows/Linux/macOS |
| Screen rotate / orientation lock | **Mobile side rail** (`overlay:1352-1421`) | nothing (rotates / locks orientation) | Rare | — |
| Lock controls (hide UI) | **Mobile side rail** (`overlay:1424-1451`); unlock via HUD (`player_gesture_hud.dart:296`) | nothing | Occasional | — |
| **· Navigation & system** | | | | |
| Back | **Both** — TV top bar (`tv_controls:249-282`), mobile top bar (`overlay:113-129`); remote/keyboard Back handled in `player_key_handler.dart:42-69` | pops the player | Frequent | — |
| Resume banner (Restart / dismiss) | **Mobile HUD only** (`player_gesture_hud.dart:344-430`) | nothing | Occasional | A saved resume position exists |
| Volume / brightness gestures | **Mobile gestures** (`video_view:203-204`, HUD `:892-895`); TV/desktop volume via D-pad ↑/↓ and M (`player_key_handler.dart:220-251`) | HUD indicator | Frequent | TV: only while controls are visible |

*Display-only, not counted as controls:* the TV top-bar quality badge (`tv_controls:375-390`) and the
Live badge (`tv_controls:634-699`, `overlay:629-684`) — labels, not buttons.

## 2. Proposed grouping — 4 categories, both platforms

**`Source` · `Audio` · `Video` · `Extras`.** Two doors reuse **existing** surfaces: `Source` →
`PlayerServerDialog` + `PlayerQualityDialog`; `Audio` → the existing Audio & Subtitles sheet, which
only grows two rows (Audio-only, Equalizer). Only `Video` and `Extras` need a new grouped sheet.

| Category | Contains | Entry opens | Lands on |
|---|---|---|---|
| **Source** | Server/provider · stream · quality tier | existing two-step source flow (`player_server_sheet.dart:48-639`), then quality tiers (`:642-1148`) | both |
| **Audio** | Audio track · dubbed track · subtitles (embedded/online) · subtitle appearance · audio sync · subtitle sync · audio enhancements/EQ · **audio-only** · *(+ speed moves out to Video)* | existing `PlayerAudioSubtitlesSheet` (`player_audio_subtitles_sheet.dart:77`) + one new header row for **Audio-only** and one for **Equalizer & Volume Boost** (opens `PlayerAudioTunerSheet`) | both |
| **Video** | Fit/Cover · Picture tuner · Playback speed · Stats for Nerds | new `PlayerVideoSheet`: 4 rows | both |
| **Extras** | **Session:** sleep timer · watch party · **Playback:** next episode (series) · **Output:** cast (mobile) · external player · fullscreen (desktop) · **Device:** lock controls · screen rotate (mobile) | new `PlayerExtrasSheet` with 3–4 labelled sections | TV: Session only (2 rows) · mobile: all |

**Uncategorised by design.** Three inventoried entries stay outside the four categories: Back (chrome,
both platforms), the resume banner (a transient toast, mobile only) and the volume/brightness gestures
(no on-screen button except the HUD). They are listed in §5 as do-not-touch.

**Episodes on mobile is out of scope.** The TV bar keeps its contextual Episodes pill; mobile has no
picker today, and this plan does **not** add one to Extras — adding a control the overlay never had is a
separate feature proposal (§6).

### TV bar: what stays one-tap, what moves

| TV action row | Before | After |
|---|---|---|
| Contextual slot 1 | Play/Pause pill (Live only) | **unchanged** (Live only) |
| Contextual slot 2 | Skip Intro / Episodes | **unchanged** — same slot, still one tap (`tv_controls:800-899`) |
| Direct | Audio & Subs | **stays one-tap** (`tv_controls:901-957`) |
| Direct | Source · quality | **stays one-tap** (`tv_controls:965-1013`), tooltip/label unchanged |
| Category | — | **Video** → new sheet |
| Category | — | **Extras** → new sheet |
| Moves off the bar | Speed → **Video** · Fit → **Video** · Stats → **Video** · Picture → **Video** · Audio EQ → **Audio** · Audio-Only → **Audio** · Sleep → **Extras** · Party → **Extras** | |
| Not in the row | Restart stays on its own row above the seekbar (`tv_controls:395-449`) | **unchanged** |

**Explicit left-to-right order (after):** `[Play/Pause — Live only]` `[Skip Intro/Outro — while active]`
`[Episodes — series, when no skip]` `[Audio & Subs]` `[Source]` `[Video]` `[Extras]`.
Contextual pill(s) stay at the left edge as they are today (at most one shows at a time);
**`Audio & Subs` is the first non-conditional pill and is therefore the fixed D-pad anchor** (see §4.1).

### Mobile: what stays, what moves

| Mobile surface | Before | After |
|---|---|---|
| Top bar (landscape) | Source · Audio · **Cast** · **Sleep** · More = **5** | Source · Audio · Video · Extras = **4** |
| Top bar (portrait) | More only = 1 | same single **More** → 4-row category sheet (390 dp cannot fit 4 icons + title; `overlay:95-214`) |
| Bottom bar | Play/Pause · seek · skip · **Fit** · PiP = **5** | seek · skip · PiP = **3** (play/pause is a duplicate of the 64 px centre CTA; Fit → Video) |
| Centre quick row | −10 s · play/pause · +30 s = 3 | unchanged |
| Side rail | rotate · lock = 2 | unchanged |
| More menu | **16 rows** (`overlay:1015-1346`) | **4 category rows** |

### Mobile More menu → destination map (all 16 rows)

| Row today | Destination |
|---|---|
| Picture Tuner (Display) | Video |
| Audio Equalizer & Clarity | Audio |
| Audio-Only Mode (Low Power) | Audio |
| Watch Party (LAN Sync) | Extras → Session |
| Sleep Timer | Extras → Session (also leaves the top bar) |
| Video Quality | Source (delete duplicate row — the Source pill is on the bar) |
| Streaming Servers | Source (delete duplicate row) |
| Audio & Subtitles | Audio (delete duplicate row) |
| Fit Screen / Aspect Ratio | Video (delete duplicate row) |
| Playback Speed | Video |
| Cast to TV / Device | Extras → Output (also leaves the top bar) |
| Picture-in-Picture | **delete** duplicate — PiP stays on the bottom bar |
| Next Episode | Extras → Playback |
| Open in External Player | Extras → Output |
| Enter/Exit Fullscreen | Extras → Output |
| Stats for Nerds | Video |

### Evaluated against the suggested shape (5 one-tap + 3 category entries)

Adopted with one adjustment: **4 fixed doors + 1 contextual slot**, not 3 doors and not 5 one-taps.
(The two contextual variants — Live play/pause, Skip-or-Episodes — are mutually exclusive, so the row
never shows both.)
Reasons: (a) four categories need four doors — with three, one category is unreachable; (b) two of the
doors cost zero new UI; (c) the leftover one-tap candidates (Fit, Speed) are occasional actions on a TV
and cost exactly one extra D-pad press inside Video, while the 11-pill row costs a scroll *and* a
discovery failure for anything past the ~6th pill on a 1080p screen.

## 3. Rationale, one line each

Counts this section refers to:

| Metric | Before | After |
|---|---|---|
| TV action-row pills (VOD series, worst case) | 11 | **5** |
| TV action-row pills (Live TV) | 10 | **5** |
| TV action-row pills (VOD feature film) | 10 | **4** |
| TV pills whose only job is a niche feature sheet (Speed, Fit, Stats, Picture, Audio EQ, Audio-Only, Sleep, Party) | 8 | **0** |
| Mobile top-bar entries | 5 | **4** |
| Mobile bottom-bar entries | 5 | **3** |
| Mobile More-menu rows | 16 | **4 category rows** |
| Duplicate entry points deleted | — | **5**, plus the speed accordion removed |

| Decision | Why |
|---|---|
| TV bar 11 → max 5 (4 fixed + 1 contextual) | The row is a horizontal scroller (`tv_controls:718-723`); anything past the ~6th pill is effectively hidden from a D-pad user. |
| Source stays one pill, not server + quality | Already merged and self-conditional (`tv_controls:965`, label `:105-118`); splitting it re-creates the dead-end "quality sheet with one option" problem documented at `tv_controls:960-964`. |
| Audio & Subs stays a direct one-tap | It is the most-reopened surface (tracks, dubs, subs, sync) and already has a TV two-column layout (`player_audio_subtitles_sheet.dart:543-601`) — nesting it adds a press for no gain. |
| Speed and Fit move into Video | Both are per-stream preferences, not per-session actions; both currently sit at index 4–6 of a scrolled row, so the one-tap is mostly theoretical. |
| Stats and Picture move into Video | Rare diagnostic/setup surfaces (`tv_controls:1202`, `:1264`); nobody needs them mid-scene. |
| Audio EQ and Audio-Only move into Audio | They are audio-output decisions and the Audio door already exists; this removes two pills for zero new modal depth. |
| Sleep timer and Watch party move into Extras | Both are "leave it running" actions; sleep is occasional and party is rare. |
| Restart stays above the seekbar, not in the row | It reads as part of the timeline, not as a feature; `tv_controls:395-449` already gives it its own row and an ↑/↓ contract. |
| Skip Intro/Episodes keep the contextual slot | Highest-value contextual control for a series; burying it in a sheet costs two presses exactly when the user has ~10 s to act. |
| Mobile keeps the Source and Audio icons | Same argument as TV: the two most-used leaves stay one tap; only the junk drawer is replaced. |
| Mobile More menu 16 → 4 categories | 16 undifferentiated rows with duplicated entries is the actual overwhelm on a phone; categories make the list scannable and kill five duplicate rows. |
| Mobile loses its bottom-bar play/pause | Two play/pause buttons already exist on mobile (centre 64 px CTA `video_view:737`, bottom bar `overlay:590`); keeping the bigger one and deleting the smaller loses nothing. |
| Mobile Fit moves to Video | One home for the toggle on both platforms beats a platform-specific shortcut nobody can discover consistently. |
| Mobile Extras is sectioned (Session/Playback/Output/Device) | Keeps the junk drawer scannable without inventing a fifth category. |
| Delete duplicates rather than move them | Quality, servers, audio, fit, PiP, speed and night-mode each exist in more than one place today; duplication is why users cannot build a map of the bar. |
| Audio-only gets a row in the Audio sheet, not a new pill | It is a mode, not a feature; one row next to the tracks is where users look for it. |

## 4. TV D-pad constraints the implementation must respect

1. **Focus order: seekbar → bar, and bar → sheet.** On reveal focus lands on the seekbar (VOD) or the
   Live play/pause pill (`player_controls_visibility_mixin.dart:112-124`). D-pad ↓ from the seekbar
   targets `playPauseTvFocusNode` (`tv_controls:501-505`); on VOD there is no play/pause pill, so today
   the first pill borrows that node conditionally (`tv_controls:905-911`). After the regroup, attach
   `playPauseTvFocusNode` to **`Audio & Subs` — the first non-conditional pill** — in every
   configuration (order in §2), delete the conditional, and keep the contextual pill reachable with ←
   from it. Every pill's ↑ must return to the seekbar (`requestUpFocus`, `tv_controls:710-716`).
2. **One autofocus per dialog/sheet.** `TvPopupScope` already falls back to
   `DpadMarks.initialCandidate(...) ?? candidates.first` (`lib/ui/widgets/tv/tv_popup_scope.dart:61-110`),
   so a sheet must mark **exactly one** `TvFocusable(autofocus: true)` — the first row — and never two.
   Each new sheet is wrapped in `TvPopupScope` for focus trapping and Escape/Back dismissal
   (`tv_popup_scope.dart:165-177`).
3. **Focus restoration on pop.** A category sheet that pushes a leaf sheet (Video → Picture tuner) must
   re-focus the row that launched it when the leaf pops (guardrail: restore focus after route pop,
   `.agents/skills/tv-dpad-navigation-guardian/SKILL.md`); nested depth is capped at 2.
4. **Sheets must scroll — including the two legacy ones.** New sheets use `SafeArea` + `Flexible` +
   `ListView`/`SingleChildScrollView` like `player_server_sheet.dart:169`, `:270`, `:324`.
   Because the sleep timer and speed become leaves of `Extras` and `Video`, the two sheets that are
   **not** scrollable today must be refactored in the same change: `PlayerSleepTimerSheet`'s
   `Column` (`player_sleep_timer_sheet.dart:114`) and `PlayerSpeedSheet`'s `Wrap`
   (`player_speed_dialog.dart:44`) both need `SafeArea` + a scrollable body, verified at 720p and in
   short landscape. Do not ship the new doors on top of the old overflow.
5. **Bar geometry.** The row is inside `SizedBox(height: 60)` with `clipBehavior: Clip.none`
   (`tv_controls:718-723`) and pills scale 1.12×; keep that height and clip behaviour, and keep every
   pill's content to one line at 13 px so the scroll row never grows.
6. **Only three pills may be conditional:** Live play/pause, Skip-or-Episodes (one slot, `if/else` at
   `tv_controls:800`, `:849`), and the Source visibility guard (`tv_controls:965`). The first two are
   mutually exclusive, so the row shows at most **5** pills. `Audio & Subs`, `Source`, `Video` and
   `Extras` are never conditional, so the bar cannot shrink below 4 and focus has a stable anchor.
7. **Separate focus groups.** Sheet headers hold competing targets (title • Reset • Close, e.g.
   `player_picture_tuner_sheet.dart:243-289`); wrap independent groups in `FocusTraversalGroup`
   (`OrderedTraversalPolicy`) so spatial scoring cannot jump past the next row.
8. **Horizontal chip rows inside sheets** (E.Q. presets `player_picture_tuner_sheet.dart:294-372`,
   speed presets `player_speed_dialog.dart:57`) need `clipBehavior: Clip.none` and a
   `SizedBox` height ≥ chip height + 20 px.
9. **Back must not double-fire.** The player consumes Back as "hide controls first" and has a 400 ms
   anti-double-pop guard (`player_key_handler.dart:42-69`, `player_screen.dart:957-969`). Every new
   sheet is a route above the player and must dismiss itself without reaching that guard.
10. **No focusable element may sit behind a sheet's scroll viewport** without `Scrollable.ensureVisible`
    — `TvFocusable` already does this on focus change; keep using `TvFocusable`, never bare `InkWell`,
    on TV surfaces (guardrail rule 1 in the TV navigation skill above).

## 5. What NOT to change

- **Play/pause *behaviour*.** Seekbar Select (`tv_controls:481-487`), hardware media keys
  (`player_key_handler.dart:72-112`), tap-to-toggle, and the 64 px mobile centre CTA. (The single
  deliberate exception is the small duplicate play/pause button on the mobile bottom bar — see §3.)
- **Seek bar and its D-pad contract.** ←/→ ±10/30 s, key-repeat throttling, KeyUp finalisation
  (`tv_controls:468-517`), double-tap seek on mobile.
- **Back.** Top-bar button, remote Back hide-then-pop order, and the double-back guard.
- **Skip Intro/Outro.** It stays a contextual one-tap on both platforms.
- **Episodes on TV.** Contextual pill stays in the row.
- **Sleep-timer live badge semantics.** If the pill moves, the remaining-time state must still be
  visible on the Extras row (today `tv_controls:1181-1192`, `overlay:487-489`).
- **Active-state emphasis.** Stats, audio-only, sleep, night mode all currently light up their pill;
  the replacement sheet rows must carry the same "on" styling, and the Video/Extras doors should show a
  dot when a leaf inside is active.
- **Mobile side rail** (rotate / lock) — nobody complains about these.
- **Hotkeys** — C (subtitles), S (skip), M/F, media keys (`player_key_handler.dart:253-292`).
- **Existing sheet *content and wiring*.** The Audio & Subtitles tabs/accordions, the server/quality
  dialogs and both tuner sheets keep their current bodies and callbacks. The only edits allowed inside
  them are the two added entry rows (Audio-only, Equalizer) and the removal of the duplicate speed
  accordion.
- **System/chrome controls.** Back, the resume banner, and the volume/brightness gestures stay outside
  the four categories and unchanged — no category owns them.

## 6. Parity note (proposals, not inventory)

| Gap | Suggested placement |
|---|---|
| Speed has **3** entry points (TV pill, mobile More row, Audio-sheet accordion) | Target is **1**: the Video row → `PlayerSpeedSheet`; drop the accordion (`player_audio_subtitles_sheet.dart:1154`) |
| Mobile has no Episodes picker (`video_view:518` is TV-only) | Out of scope here — separate feature proposal; do not smuggle it into Extras |
| Night mode + gain exist in both the Audio sheet and the EQ tuner | Keep the tuner as the single home, reduce the sheet accordion to a read-only "current preset" row |
| Downloads / parental do **not** exist as player controls | Do not add them to any category; downloads start from details, parental from Settings |
