# 🌸 Dramachi Engine — Exalere Plugin

Dramachi Engine is an official community streaming addon for **Exalere**, bringing high-speed streaming for Asian Dramas (K-Drama, C-Drama, J-Drama, Thai Drama), Anime series, and Asian Cinema with fast CDN links and multi-language subtitle synchronization.

---

## ⚡ 1-Click Install in Exalere

Copy and paste this manifest URL into **Exalere &rarr; Settings &rarr; Add-ons &rarr; Add Add-on by URL**:

```text
https://abhishekrazy.github.io/Exalere/plugins/dramachi/manifest.json
```

Or click the 1-click install button on the [Exalere GitHub Plugins Directory](https://abhishekrazy.github.io/Exalere/plugins.html).

---

## 🚀 Features

- **Asian Drama Focus**: K-Dramas, C-Dramas, J-Dramas, and Asian Cinema.
- **Fast Global CDN**: Low-latency HLS/MP4 streams with fallback mirrors.
- **Synchronized Subtitles**: Multi-language subtitle tracks.
- **100% Stremio v3 Protocol Compatible**: Compatible with Exalere and Stremio apps.
- **Free Cloudflare Workers Deployment**: Deploy your own private instance in 30 seconds.

---

## 🛠️ Deploy Your Own Instance

### 1. Install Wrangler
```bash
npm install -g wrangler
```

### 2. Run Locally
```bash
wrangler dev
```

### 3. Deploy to Cloudflare Workers (Free)
```bash
wrangler deploy
```

Once deployed, your manifest will be available at:
`https://<your-worker-subdomain>.workers.dev/manifest.json`
