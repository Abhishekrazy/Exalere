# Exalere Stream Resolver Worker (Exalere Plugin Protocol)

This is a standalone, open-source stream resolver microservice compatible with the **Exalere Plugin Protocol**.

It allows users and community contributors to host scrapers and stream resolvers outside of the official Exalere application, ensuring the main app stays 100% compliant with Google Play Store policies.

---

## 🚀 Free 1-Click Cloudflare Workers Deployment

### Option A: Using Wrangler CLI
1. Install Wrangler:
   ```bash
   npm install -g wrangler
   ```
2. Login to your free Cloudflare account:
   ```bash
   wrangler login
   ```
3. Deploy the worker:
   ```bash
   wrangler deploy
   ```
4. Copy your worker URL (e.g. `https://exalere-stream-worker.<your-subdomain>.workers.dev`).

### Option B: Using Cloudflare Web Dashboard (Zero Install)
1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) -> **Workers & Pages** -> **Create Application**.
2. Click **Create Worker** -> Name it `exalere-stream-worker` -> Click **Deploy**.
3. Click **Edit Code**, paste the contents of [`worker.js`](worker.js), and click **Deploy**.
4. Copy your Worker URL.

---

## 📱 How to Install into Exalere

1. Open **Exalere** on your Phone, Tablet, Windows PC, or Android TV.
2. Go to **Settings** -> **Stream Plugins**.
3. Tap **Add Plugin** (or **Add Plugin by URL** on TV).
4. Paste your Worker URL (or append `/manifest.json`).
5. Tap **Install**. The plugin will immediately activate and start providing streams for movies and TV shows!

---

## 🛠️ Adding Custom Scrapers

To scrape new sources or providers, modify the `resolveStreams(type, id)` function in `worker.js`:
- `type`: `'movie'` or `'series'`
- `id`: IMDb ID (e.g., `tt0137523`) or Series key (e.g., `tt0944947:1:1`)
- Return an array of stream objects following the Exalere Plugin Protocol:
  ```json
  {
    "name": "Server Name\n1080p",
    "title": "Stream Description",
    "url": "https://stream-url.m3u8",
    "behaviorHints": {
      "proxyHeaders": {
        "request": {
          "Referer": "https://...",
          "User-Agent": "..."
        }
      }
    }
  }
  ```
