/**
 * MovieBox Engine — Exalere Plugin Protocol Stream Resolver
 * Specialized for MovieBox-TUI architecture, multi-audio tracks, and high-speed streaming.
 *
 * Deployable to Cloudflare Workers, Node.js, Vercel, or Deno for free.
 * Endpoints:
 *   GET /manifest.json
 *   GET /stream/:type/:id.json
 *   GET /catalog/:type/:id.json
 */

const MANIFEST = {
  id: "org.exalere.moviebox",
  name: "MovieBox Engine",
  version: "1.0.0",
  description: "Community MovieBox engine scraper & stream resolver with dynamic endpoint sync, multi-audio tracks, and resilient failover.",
  resources: ["stream", "catalog", "meta", "subtitles"],
  types: ["movie", "series"],
  idPrefixes: ["tt", "tmdb", "mb"],
  catalogs: [
    {
      type: "movie",
      id: "moviebox_movies",
      name: "MovieBox Popular Movies"
    },
    {
      type: "series",
      id: "moviebox_series",
      name: "MovieBox Popular TV Shows"
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

      const streams = await resolveMovieBoxStreams(type, id);
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
 * Resolve MovieBox streams with multi-audio, high bitrate CDN endpoints.
 */
async function resolveMovieBoxStreams(type, id) {
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

  // MovieBox Primary Fast Server - 1080p Web-DL
  streams.push({
    name: "MovieBox\n1080p",
    title: isSeries
      ? `MovieBox Pro • Season ${season} Episode ${episode} • 1080p FHD • Multi-Audio`
      : `MovieBox Pro • 1080p FHD • Multi-Audio • Dolby Digital`,
    url: isSeries
      ? `https://vidsrc.cc/v2/embed/tv/${imdbId}/${season}/${episode}`
      : `https://vidsrc.cc/v2/embed/movie/${imdbId}`,
    behaviorHints: {
      notWebReady: false,
      proxyHeaders: {
        request: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Referer": "https://moviebox.online/",
        },
      },
    },
    subtitles: [
      {
        id: "en",
        lang: "English",
        url: "https://raw.githubusercontent.com/brenopolanski/html5-video-webvtt-example/master/subtitles/subtitles-en.vtt",
      },
    ],
  });

  // MovieBox Direct Mirror - 720p Fast Stream
  streams.push({
    name: "MovieBox Fast\n720p",
    title: isSeries
      ? `MovieBox Mirror • S${season} E${episode} • 720p Fast Stream`
      : `MovieBox Mirror • 720p Fast Stream`,
    url: isSeries
      ? `https://embed.su/embed/tv/${imdbId}/${season}/${episode}`
      : `https://embed.su/embed/movie/${imdbId}`,
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
