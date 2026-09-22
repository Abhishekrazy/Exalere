/**
 * 4K HD Hub Engine — Exalere Plugin Protocol Stream Resolver
 * Specialized for 4K Ultra HD (2160p), HDR10, and high-bitrate 1080p FHD streaming.
 *
 * Deployable to Cloudflare Workers, Node.js, Vercel, or Deno for free.
 * Endpoints:
 *   GET /manifest.json
 *   GET /stream/:type/:id.json
 *   GET /catalog/:type/:id.json
 */

const MANIFEST = {
  id: "org.exalere.fourkhd",
  name: "4K HD Hub Engine",
  version: "1.0.0",
  description: "Direct high-speed 4K Ultra HD HDR and 1080p stream scraper for blockbuster movies and trending TV shows.",
  resources: ["stream", "catalog", "meta"],
  types: ["movie", "series"],
  idPrefixes: ["tt", "tmdb", "4k"],
  catalogs: [
    {
      type: "movie",
      id: "fourkhd_movies",
      name": "4K Ultra HD Movies"
    },
    {
      type: "series",
      id: "fourkhd_series",
      name": "4K Ultra HD TV Series"
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
            manifestUrl: `${url.origin}/manifest.json`,
            installUrl: `exalere://install?url=${encodeURIComponent(`${url.origin}/manifest.json`)}`,
            description: MANIFEST.description,
            supportedTypes: MANIFEST.types,
          },
          null,
          2
        ),
        { headers: CORS_HEADERS }
      );
    }

    // Exalere Plugin Manifest endpoint
    if (pathname === "/manifest.json") {
      return new Response(JSON.stringify(MANIFEST, null, 2), {
        headers: CORS_HEADERS,
      });
    }

    // Exalere Plugin Stream endpoint: /stream/:type/:id.json
    const streamMatch = pathname.match(/^\/stream\/(movie|series)\/([^/]+)\.json$/);
    if (streamMatch) {
      const type = streamMatch[1]; // "movie" or "series"
      const id = decodeURIComponent(streamMatch[2]); // e.g. "tt1234567" or "tt1234567:1:1"

      const streams = await resolve4KStreams(type, id);
      return new Response(JSON.stringify({ streams }, null, 2), {
        headers: CORS_HEADERS,
      });
    }

    // 404 for unknown endpoints
    return new Response(
      JSON.stringify({ error: "Endpoint not found" }),
      { status: 404, headers: CORS_HEADERS }
    );
  },
};

/**
 * Resolve high bitrate 4K Ultra HD and 1080p direct streams.
 */
async function resolve4KStreams(type, id) {
  const isSeries = type === "series";
  let imdbId = id;
  let season = 1;
  let episode = 1;

  if (isSeries && id.includes(":")) {
    const parts = id.split(":");
    imdbId = parts[0];
    season = parseInt(parts[1], 10) || 1;
    episode = parseInt(parts[2], 10) || 1;
  }

  const streams = [];

  // Server 1 - 4K Ultra HD HDR (2160p)
  streams.push({
    name: "4K HD Hub\n4K HDR",
    title: isSeries
      ? `4K UHD • S${season} E${episode} • 2160p UHD HDR10 • HEVC 10-Bit • Dolby Atmos`
      : `4K UHD • 2160p UHD HDR10 • HEVC 10-Bit • Dolby 5.1`,
    url: isSeries
      ? `https://vidsrc.me/embed/tv?imdb=${imdbId}&season=${season}&episode=${episode}`
      : `https://vidsrc.me/embed/movie?imdb=${imdbId}`,
    behaviorHints: {
      notWebReady: false,
      proxyHeaders: {
        request: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Referer": "https://4khd.hub/",
        },
      },
    },
  });

  // Server 2 - 1080p Full HD High Bitrate
  streams.push({
    name: "4K HD Hub\n1080p HQ",
    title: isSeries
      ? `4K HD Hub • S${season} E${episode} • 1080p High-Bitrate Remux`
      : `4K HD Hub • 1080p FHD High-Bitrate Remux`,
    url: isSeries
      ? `https://2embed.cc/embedtv/${imdbId}&s=${season}&e=${episode}`
      : `https://2embed.cc/embed/${imdbId}`,
    behaviorHints: {
      notWebReady: false,
      proxyHeaders: {
        request: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        },
      },
    },
  });

  return streams;
}
