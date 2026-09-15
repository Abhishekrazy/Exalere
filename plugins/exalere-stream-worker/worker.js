/**
 * Exalere Stream Resolver Worker
 * Exalere Plugin Protocol compliant endpoint.
 *
 * Deployable to Cloudflare Workers, Node.js, Vercel, or Deno for free.
 * Exposes:
 *   GET /manifest.json
 *   GET /stream/:type/:id.json
 */

const MANIFEST = {
  id: "community.exalere.worker",
  name: "Exalere Community Plugin",
  version: "1.0.0",
  description: "External community stream resolver for Exalere",
  resources: ["stream"],
  types: ["movie", "series"],
  idPrefixes: ["tt", "tmdb"],
  catalogs: [],
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
            instruction: "Copy this URL into Exalere -> Settings -> Stream Plugins",
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

      const streams = await resolveStreams(type, id);
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
 * Resolve streams for a given media title.
 * Custom scraper logic (e.g. FourKHDHub, MovieBox, VidSrc, etc.) can be placed here.
 */
async function resolveStreams(type, id) {
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

  // Sample stream definition demonstrating Exalere Plugin Protocol
  // Add scrapers here to scrape target servers and return direct stream URLs:
  streams.push({
    name: "Exalere Fast Server\n1080p",
    title: `${imdbId} • Multi-Audio • 1080p Web-DL`,
    url: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
    behaviorHints: {
      notWebReady: false,
      proxyHeaders: {
        request: {
          "User-Agent":
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        },
      },
    },
    subtitles: [
      {
        id: "1",
        lang: "English",
        url: "https://raw.githubusercontent.com/brenopolanski/html5-video-webvtt-example/master/subtitles/subtitles-en.vtt",
      },
    ],
  });

  return streams;
}
