# 💎 4K HD Hub Engine — Exalere Plugin

4K HD Hub Engine is a community streaming addon for **Exalere**, designed to scrape and resolve high-bitrate 4K Ultra HD (2160p), HDR10, HEVC 10-bit, and 1080p Full HD direct streams for movies and popular TV shows.

---

## ⚡ 1-Click Install in Exalere

Copy and paste this manifest URL into **Exalere &rarr; Settings &rarr; Add-ons &rarr; Add Add-on by URL**:

```text
https://abhishekrazy.github.io/Exalere/plugins/fourkhd/manifest.json
```

Or click the 1-click install button on the [Exalere GitHub Plugins Directory](https://abhishekrazy.github.io/Exalere/plugins.html).

---

## 🚀 Features

- **4K Ultra HD & HDR10**: High bitrate 2160p and 1080p remux streams.
- **Direct Stream Scraper**: Direct HTTP/HLS streaming with high-speed mirrors.
- **Dolby Audio Support**: Multi-channel 5.1 and Atmos pass-through.
- **100% Stremio v3 Protocol Compatible**: Works with Exalere on Android TV, Mobile, and Windows Desktop.
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
