/**
 * VidSrc Engine — Exalere Plugin Protocol Stream Resolver
 * Powered by VidSrc multi-mirror streaming endpoints.
 *
 * Deployable to Cloudflare Workers, Node.js, Vercel, or Deno for free.
 * Endpoints:
 *   GET /manifest.json
 *   GET /catalog/:type/:id.json
 *   GET /stream/:type/:id.json
 */

const MANIFEST = {
  id: "org.exalere.vidsrc",
  name: "VidSrc Engine",
  version: "1.0.0",
  description: "Multi-mirror streaming and discovery engine for movies and TV shows powered by VidSrc (vidsrc.sh).",
  resources: ["stream", "catalog", "meta"],
  types: ["movie", "series"],
  idPrefixes: ["tt", "tmdb", "vidsrc"],
  catalogs: [
    {
      type: "movie",
      id: "vidsrc_movies",
      name: "VidSrc Latest Movies"
    },
    {
      type: "series",
      id: "vidsrc_series",
      name: "VidSrc Latest TV Shows"
    }
  ],
  behaviorHints: {
    configurable: false,
    configurationRequired: false
  }
};

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "*",
  "Access-Control-Allow-Methods": "GET, HEAD, OPTIONS",
  "Content-Type": "application/json; charset=utf-8",
};

const BASE_MIRRORS = [
  "https://vidsrc.sh",
  "https://vidsrcme.ru",
  "https://vidsrcme.su",
  "https://vidsrc-me.ru",
  "https://vidsrc-me.su",
  "https://vidsrc-embed.ru",
  "https://vidsrc-embed.su",
  "https://vsrc.su",
  "https://vidsrc2.ru"
];

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const pathname = url.pathname;

    // Handle preflight CORS requests
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: CORS_HEADERS });
    }

    // Root Info endpoint
    if (pathname === "/" || pathname === "") {
      return new Response(
        JSON.stringify(
          {
            status: "online",
            plugin: MANIFEST.name,
            version: MANIFEST.version,
            manifest: "/manifest.json"
          },
          null,
          2
        ),
        { headers: CORS_HEADERS }
      );
    }

    // Manifest endpoint
    if (pathname === "/manifest.json") {
      return new Response(JSON.stringify(MANIFEST, null, 2), {
        headers: CORS_HEADERS
      });
    }

    // Catalog endpoint: GET /catalog/:type/:id.json
    const catalogMatch = pathname.match(/^\/catalog\/(movie|series)\/([^\/]+)\.json$/);
    if (catalogMatch) {
      const [_, type, catalogId] = catalogMatch;
      const isSeries = type === "series";
      const targetUrl = isSeries
        ? "https://vidsrc.sh/tvshows/latest/page-1.json"
        : "https://vidsrc.sh/movies/latest/page-1.json";

      try {
        const resp = await fetch(targetUrl, {
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            "Accept": "application/json"
          }
        });

        if (resp.ok) {
          const data = await resp.json();
          const results = data.result || [];
          const metas = results.map(item => ({
            id: item.imdb_id || String(item.tmdb_id) || item.title,
            name: item.title || item.show_title,
            type: isSeries ? "series" : "movie",
            poster: item.poster,
            description: `Released in ${item.year || "recent"}. Powered by VidSrc.`
          }));

          return new Response(JSON.stringify({ metas }), { headers: CORS_HEADERS });
        }
      } catch (e) {
        // Fallback to empty metas
      }
      return new Response(JSON.stringify({ metas: [] }), { headers: CORS_HEADERS });
    }

    // Stream endpoint: GET /stream/:type/:id.json
    const streamMatch = pathname.match(/^\/stream\/(movie|series)\/([^\/]+)\.json$/);
    if (streamMatch) {
      const [_, type, mediaId] = streamMatch;
      const isSeries = type === "series";
      const parts = mediaId.split(":");
      const id = parts[0];
      const season = parts[1] || "1";
      const episode = parts[2] || "1";

      const queryParams = isSeries
        ? "autoplay=1&autonext=1&ds_lang=en"
        : "autoplay=1&ds_lang=en";

      const streams = BASE_MIRRORS.map((mirror, index) => {
        const host = new URL(mirror).host;
        const embedUrl = isSeries
          ? `${mirror}/embed/tv/${id}/${season}/${episode}?${queryParams}`
          : `${mirror}/embed/movie/${id}?${queryParams}`;

        return {
          name: `VidSrc\n${host}`,
          title: `Mirror ${index + 1} (${host}) • Web Embed 1080p`,
          url: embedUrl,
          behaviorHints: {
            notWebReady: false,
            proxyHeaders: {
              request: {
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
                "Referer": `${mirror}/`
              }
            }
          }
        };
      });

      return new Response(JSON.stringify({ streams }), { headers: CORS_HEADERS });
    }

    return new Response(
      JSON.stringify({ error: "Endpoint not found" }),
      { status: 404, headers: CORS_HEADERS }
    );
  }
};
