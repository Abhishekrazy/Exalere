# 🎬 VidSrc Engine — Exalere Plugin

VidSrc Engine is an official community streaming addon for **Exalere**, bringing multi-mirror fallback streaming and discovery feeds for blockbuster movies and popular TV shows powered by VidSrc architecture (vidsrc.sh).

---

## ⚡ 1-Click Install in Exalere

Copy and paste this manifest URL into **Exalere &rarr; Settings &rarr; Add-ons &rarr; Add Add-on by URL**:

```text
https://abhishekrazy.github.io/Exalere/plugins/vidsrc/manifest.json
```

Or click the 1-click install button on the [Exalere GitHub Plugins Directory](https://abhishekrazy.github.io/Exalere/plugins.html).

---

## 🚀 Features

- **Multi-Mirror Redundancy**: 9 redundant VidSrc mirrors with automatic failover.
- **Embedded Web Streams**: Responsive HTML5 embed streams with autoplay, autonext, and English captions.
- **Catalog Feeds**: Real-time discovery feeds for latest releases and trending content.
- **100% Stremio v3 Protocol Compatible**: Works with Exalere and Stremio apps.
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
