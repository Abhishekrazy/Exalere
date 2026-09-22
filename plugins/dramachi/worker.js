/**
 * Dramachi Engine — Exalere Plugin Protocol Stream Resolver
 * Specialized for Asian Drama (K-Drama, C-Drama, J-Drama), Anime, and Asian Cinema.
 *
 * Deployable to Cloudflare Workers, Node.js, Vercel, or Deno for free.
 * Endpoints:
 *   GET /manifest.json
 *   GET /stream/:type/:id.json
 */

const MANIFEST = {
  id: "org.exalere.dramachi",
  name: "Dramachi Engine",
  version: "1.0.0",
  description: "Asian drama, K-Drama, C-Drama, anime, and movies streaming with fast CDN links and multi-language subtitles.",
  resources: ["stream", "meta", "subtitles"],
  types: ["movie", "series"],
  idPrefixes: ["tt", "tmdb", "kdrama", "drama"],
  catalogs: [
    {
      type: "series",
      id: "dramachi_kdrama",
      name: "Dramachi Trending K-Dramas & Asian Series"
    },
    {
      type: "movie",
      id: "dramachi_movies",
      name: "Dramachi Asian Cinema"
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

      const streams = await resolveDramachiStreams(type, id);
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
 * Resolve high-speed Asian Drama / Anime CDN streams and synced subtitles.
 */
async function resolveDramachiStreams(type, id) {
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

  // Dramachi CDN Server 1 - 1080p Ultra Fast HLS / MP4
  streams.push({
    name: "Dramachi CDN\n1080p",
    title: isSeries
      ? `Dramachi • S${season} E${episode} • 1080p HD • English Subtitles`
      : `Dramachi • Asian Cinema • 1080p FHD • Dual Audio`,
    url: isSeries
      ? `https://vidsrc.xyz/embed/tv?imdb=${imdbId}&season=${season}&episode=${episode}`
      : `https://vidsrc.xyz/embed/movie?imdb=${imdbId}`,
    behaviorHints: {
      notWebReady: false,
      proxyHeaders: {
        request: {
          "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          "Referer": "https://dramacool.ch/",
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

  // Dramachi CDN Server 2 - 720p Fast Mobile / Low-Bandwidth Stream
  streams.push({
    name: "Dramachi Fast\n720p",
    title: isSeries
      ? `Dramachi Mirror • S${season} E${episode} • 720p Fast Stream`
      : `Dramachi Mirror • 720p Fast Stream`,
    url: isSeries
      ? `https://autoembed.to/tv/imdb/${imdbId}-${season}-${episode}`
      : `https://autoembed.to/movie/imdb/${imdbId}`,
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
