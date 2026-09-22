# 🎬 MovieBox Engine — Exalere Plugin

MovieBox Engine is a community media streaming addon for **Exalere**, providing access to high-speed MovieBox-TUI endpoints, multi-audio tracks, TV show season/episode routing, and resilient automatic failover mirrors.

---

## ⚡ 1-Click Install in Exalere

Copy and paste this manifest URL into **Exalere &rarr; Settings &rarr; Add-ons &rarr; Add Add-on by URL**:

```text
https://abhishekrazy.github.io/Exalere/plugins/moviebox/manifest.json
```

Or click the 1-click install button on the [Exalere GitHub Plugins Directory](https://abhishekrazy.github.io/Exalere/plugins.html).

---

## 🚀 Features

- **Extensive Catalog**: Global movies and trending TV shows.
- **Multi-Audio**: Audio track selection (Hindi, English, Spanish, etc.).
- **Dynamic Endpoint Sync**: Scrapes high-performance backend CDN mirrors.
- **100% Stremio v3 Protocol Compatible**: Seamlessly integrates into Exalere's player server selection.
- **Free Serverless Deployment**: Easily hosted on Cloudflare Workers, Node.js, Vercel, or Deno.

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
