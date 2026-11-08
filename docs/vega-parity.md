# Vega parity — how the reference app is built, and what Exalere does differently

Status: **investigation in progress** (Kanban task 1). Everything below is either
observed from the shipped artifact, read from the reference project's public
source at the same version, or marked as an unknown.

- Reference app: `vega-org/vega-app` **v5.3.2**
- Artifact: `vega-v5.3.2.apk`, 79,244,309 bytes,
  SHA-256 `0a257a9392aceebcffd64a2c816b1109195388be272826f30b9ca438b251e65d`
  (REA evidence `ev_3dfb73bd27c54bed5f8a3de1493e166e060f4412896b5a6d7b4187a328737540`)
- Container inventory: 2,547 file entries, complete-within-view
  (REA evidence `ev_9c548089c2b5a1891ec5124bb979757ddc63dd288d817418f073e4fa11900692`)

## 1. What actually ships inside the reference APK

| Component | Observation | Why it matters to us |
|---|---|---|
| `assets/index.android.bundle` (7,140,044 B) | **Hermes bytecode** (magic `c6 1f bc 03`) | The JS logic cannot be read as text from the APK; the readable equivalent is the tagged source tree. Do not claim "decompiled JS" from this bundle. |
| `libavcodec/avformat/avfilter/avutil/swscale/swresample`, `libffmpegJNI`, `libffmpegkit` | Full FFmpeg stack | Used for remux/transcode (cast, downloads, format repair) — not for playback (playback is ExoPlayer). |
| `libtorrent4j.so` (15.8 MB) | Bundled libtorrent | Torrent streaming is native, not a plugin. |
| `libusque.so` (13.6 MB), `libciadpi.so` | MASQUE tunnel + ByeDPI | Network bypass is shipped in-app, same conclusion we reached earlier (we use WireGuard + our own DoH/AntiDPI instead, for licence reasons). |
| `libjingle_peerconnection_so.so` (12.5 MB) | WebRTC | Cast/remote playback transport. |
| `assets/app.manifest`, `assets/app.config` | Expo updates manifest / app config | OTA update channel; not provider data. |
| **No provider manifests or `urls.json` in the APK** | Only code references | Confirms: providers are **not** bundled. They are installed from a provider *source* (GitHub repo with `manifest.json` + per-provider JS). This is why "steal the providers from the app" is impossible — there is nothing in the APK to steal. |

## 2. How the reference player is organised

Read from the public source at v5.3.2 (`src/lib/player/controlLayout.ts`,
`src/lib/player/playbackQuality.ts`, `src/lib/hooks/useStream.ts`).

**Controls are data, not layout.** A fixed vocabulary of 13 control ids:

```
sleep, lock, cast, audio, subtitle, speed, pip, server, resize, episodes, next,
settings, decoder
```

They are assigned to three bars — `top`, `bottom`, `more` — and the mapping is a
**user-editable setting** with drag/reorder (`PlayerControlEditor`). Two rules
are enforced by `normalizePlayerControlLayout`:

- `settings` (the "more" launcher) is always **pinned to the last slot** of
  whichever row holds it.
- The top bar is width-limited: `max(1, min(5, floor((width * 0.45 - 20) / 48)))`,
  so a wide TV shows up to 5 and a phone collapses to fewer.

**Quality is derived from the decoded track, not from the stream label.**

```
activeVideoTrack.height  →  decoded frame size  →  single-track height
                  →  only then the source's quality string ("1080p", "4K", "2x3")
```

with identical video tracks de-duplicated by `width x height : bitrate`, keeping
the selected copy. Labels like `HLS`, `HD`, `Local`, `Auto` are explicitly *not*
treated as a resolution.

**Resolution order prefers what is already on disk.** `useStream` checks a local
file path and completed downloads before hitting the network, then falls back to
the provider/episode link.

**Per-provider player surface** is thin: `server` (source list) and `audio` /
`subtitle` are separate entries; there is no merged "Audio & Subs" pill.

## 3. Gaps against Exalere

| # | Gap | Severity | What we do today | Proposed |
|---|---|---|---|---|
| 1 | Quality label is taken from `StreamSource.quality` metadata | **High** — it can claim 1080p while decoding 720p | `PlayerTvControls._sourceAndQualityLabel` / mobile label use the source string | Derive the label from the active decoded video track (mpv `video-params`), fall back to metadata only before the first frame |
| 2 | Controls are hard-coded per platform | Medium — adding/moving a control means editing two widgets | TV bar + mobile overlay enumerated inline | Adopt the id+bar model (`top`/`bottom`/`more`) with a `settings` pin, then a user-editable layout later |
| 3 | Bar density | Medium — this is the "too many options" complaint | 13 TV pills, 9 mobile slots | Category entries: `Source`, `Audio`, `Video`, `Extras` (design in `docs/player-controls-plan.md`) |
| 4 | Local file / completed download is not consulted before resolving | Medium — replays re-resolve a stream that is already on disk | Player receives sources and plays the selected one | Check downloads/local path first (parity with `useStream`) |
| 5 | Duplicate video tracks can be listed | Low | Not de-duplicated | De-duplicate by `width x height : bitrate`, keep selected |
| 6 | Provider capability failures are opaque | Medium | Self-test shows a stage as failed without a reason | Per-stage reason (HTTP status / blocked host / empty parse / gated) — Kanban task 5 |

## 4. Deliberate non-goals

- **FFmpeg remux stack**: we play with mpv, which reads the containers these
  providers serve. Adding FFmpeg is a large native surface for a case we have not
  observed failing.
- **MASQUE (`usque`)**: GPL-3.0, incompatible with the project licence. We keep
  WireGuard (`com.wireguard.android:tunnel`).
- **Bundling providers**: violates the fresh-install invariant (no playable
  provider by default) and the store-polish rule agreed earlier.

## 5. Open questions (not yet answered)

- Hermes bytecode was **not** disassembled; every JS statement above is from the
  tagged source tree, not from the APK's bytecode. To claim shipped-equals-source
  we would need a Hermes disassembler and a bundle-to-source comparison.
- No runtime capture of the reference player yet (install + screenshot on the TV
  emulator) — until then, "how it looks in motion" is source-derived only.
- Provider portability per candidate site: recorded in Kanban task 4 (viability
  table); two families are already known-blocked (TLS fingerprint, session
  unlock).
