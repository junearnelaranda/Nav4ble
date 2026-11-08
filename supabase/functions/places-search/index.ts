// Google Places search for the NavAble Explore tab and the admin app.
//
//   POST {query, latitude?, longitude?}  -> {places: [...]} (Text Search, New)
//   GET  ?photo=<photo name>&w=<px>       -> redirect to the photo image
//
// The Google key stays here as the GOOGLE_PLACES_API_KEY secret
// (Supabase dashboard > Edge Functions > Secrets), never in the app.
// Google's terms: results are shown live with Google attribution; NavAble
// stores only the place id, and they must not be drawn on a non-Google map.
//
// Guests can use it, so every call is counted per day (Philippine time) in
// the places_usage table, per caller (signed-in account, otherwise network
// address) and overall. Over either limit the call is refused before Google
// is asked, so nobody can run up the bill. Limits can be changed with these
// optional secrets: PLACES_SEARCH_PER_CALLER, PLACES_SEARCH_PER_DAY,
// PLACES_PHOTO_PER_CALLER, PLACES_PHOTO_PER_DAY.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SEARCH_URL = "https://places.googleapis.com/v1/places:searchText";
// Only the fields Explore shows, so each search bills at one SKU.
const FIELDS = [
  "places.id",
  "places.displayName",
  "places.formattedAddress",
  "places.shortFormattedAddress",
  "places.location",
  "places.rating",
  "places.userRatingCount",
  "places.primaryTypeDisplayName",
  "places.currentOpeningHours.openNow",
  "places.accessibilityOptions",
  "places.photos",
].join(",");
const PHOTO_NAME = /^places\/[A-Za-z0-9_-]+\/photos\/[A-Za-z0-9_-]+$/;

function limit(name: string, fallback: number): number {
  const value = Number(Deno.env.get(name));
  return Number.isInteger(value) && value > 0 ? value : fallback;
}
const LIMITS = {
  search: { perCaller: limit("PLACES_SEARCH_PER_CALLER", 20), perDay: limit("PLACES_SEARCH_PER_DAY", 60) },
  photo: { perCaller: limit("PLACES_PHOTO_PER_CALLER", 150), perDay: limit("PLACES_PHOTO_PER_DAY", 400) },
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...corsHeaders },
  });
}

const error = (status: number, code: string, message: string) =>
  json(status, { error: { code, message } });

// The signed-in account when the request carries a valid session, otherwise
// the caller's network address. Only searches check the session; photo
// requests come from image loaders that send no session.
async function callerOf(req: Request, checkSession: boolean): Promise<string> {
  const url = Deno.env.get("SUPABASE_URL");
  const token = /^Bearer\s+(eyJ[\w-]*\.[\w-]+\.[\w-]+)$/i.exec(req.headers.get("Authorization") ?? "")?.[1];
  const apiKey = req.headers.get("apikey");
  if (checkSession && url && token && apiKey) {
    try {
      const response = await fetch(`${url}/auth/v1/user`, {
        headers: { Authorization: `Bearer ${token}`, apikey: apiKey },
      });
      if (response.ok) {
        const user = await response.json().catch(() => null);
        if (typeof user?.id === "string" && user.id) return `user:${user.id}`;
      }
    } catch (_) {
      // Fall back to the network address.
    }
  }
  const address = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() ||
    req.headers.get("x-real-ip") || "unknown";
  return `ip:${address}`;
}

// Counts this call; true when it is within today's limits.
async function withinLimits(caller: string, kind: "search" | "photo"): Promise<boolean> {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) throw new Error("Supabase service settings are missing.");
  const headers: Record<string, string> = { apikey: key, "Content-Type": "application/json" };
  if (key.startsWith("eyJ")) headers.Authorization = `Bearer ${key}`;
  const response = await fetch(`${url}/rest/v1/rpc/take_places_quota`, {
    method: "POST",
    headers,
    body: JSON.stringify({
      who: caller,
      what: kind,
      per_caller: LIMITS[kind].perCaller,
      overall: LIMITS[kind].perDay,
    }),
  });
  if (!response.ok) {
    throw new Error(`Usage check failed with HTTP ${response.status}: ${await response.text()}`);
  }
  return (await response.json()) === true;
}

// deno-lint-ignore no-explicit-any
function toPlace(p: any) {
  const photo = Array.isArray(p.photos) ? p.photos[0] : undefined;
  const access = p.accessibilityOptions ?? {};
  return {
    id: p.id,
    name: p.displayName?.text ?? "",
    address: p.formattedAddress ?? "",
    shortAddress: p.shortFormattedAddress ?? p.formattedAddress ?? "",
    latitude: p.location?.latitude ?? null,
    longitude: p.location?.longitude ?? null,
    rating: typeof p.rating === "number" ? p.rating : null,
    ratingCount: typeof p.userRatingCount === "number" ? p.userRatingCount : 0,
    type: p.primaryTypeDisplayName?.text ?? null,
    openNow: p.currentOpeningHours?.openNow ?? null,
    accessibility: {
      wheelchairEntrance: access.wheelchairAccessibleEntrance ?? null,
      wheelchairRestroom: access.wheelchairAccessibleRestroom ?? null,
      wheelchairParking: access.wheelchairAccessibleParking ?? null,
      wheelchairSeating: access.wheelchairAccessibleSeating ?? null,
    },
    photo: photo?.name ?? null,
    photoAttribution: photo?.authorAttributions?.[0]?.displayName ?? null,
  };
}

async function search(req: Request, key: string): Promise<Response> {
  // deno-lint-ignore no-explicit-any
  let body: any;
  try {
    body = await req.json();
  } catch {
    body = null;
  }
  const query = typeof body?.query === "string" ? body.query.trim() : "";
  if (!query || query.length > 200) {
    return error(400, "INVALID_QUERY", "Type what you're looking for.");
  }
  const lat = Number(body?.latitude);
  const lng = Number(body?.longitude);
  const hasCenter = Number.isFinite(lat) && Number.isFinite(lng) &&
    Math.abs(lat) <= 90 && Math.abs(lng) <= 180;

  if (!(await withinLimits(await callerOf(req, true), "search"))) {
    return error(429, "DAILY_LIMIT", "Place search has reached today's limit. Try again tomorrow.");
  }

  const response = await fetch(SEARCH_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": key,
      "X-Goog-FieldMask": FIELDS,
    },
    body: JSON.stringify({
      textQuery: query,
      pageSize: 20,
      languageCode: "en",
      regionCode: "PH",
      ...(hasCenter && {
        locationBias: {
          circle: { center: { latitude: lat, longitude: lng }, radius: 5000 },
        },
      }),
    }),
  });
  if (!response.ok) {
    console.error("places-search: Google returned", response.status, await response.text());
    return error(502, "PLACES_FAILED", "Place search is unavailable right now.");
  }
  const data = await response.json();
  const places = (Array.isArray(data.places) ? data.places : [])
    .map(toPlace)
    .filter((p: { id?: string; name: string }) => p.id && p.name);
  return json(200, { places });
}

async function photo(req: Request, url: URL, key: string): Promise<Response> {
  const name = url.searchParams.get("photo") ?? "";
  const width = Math.min(Math.max(Number(url.searchParams.get("w")) || 600, 100), 1200);
  if (!PHOTO_NAME.test(name)) {
    return error(400, "INVALID_PHOTO", "Unknown photo.");
  }
  if (!(await withinLimits(await callerOf(req, false), "photo"))) {
    return error(429, "DAILY_LIMIT", "Photos have reached today's limit.");
  }
  // skipHttpRedirect returns the image URL (no key in it) instead of the image.
  const response = await fetch(
    `https://places.googleapis.com/v1/${name}/media?maxWidthPx=${width}&skipHttpRedirect=true&key=${key}`,
  );
  const data = await response.json().catch(() => null);
  if (!response.ok || typeof data?.photoUri !== "string") {
    return error(404, "PHOTO_UNAVAILABLE", "Photo unavailable.");
  }
  return new Response(null, {
    status: 302,
    headers: {
      Location: data.photoUri,
      "Cache-Control": "public, max-age=86400",
      ...corsHeaders,
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  // Only calls carrying the app's Supabase key; cheap guard against random hits.
  const url = new URL(req.url);
  if (!req.headers.get("apikey") && !url.searchParams.get("apikey")) {
    return error(401, "UNAUTHORIZED", "Missing app key.");
  }
  const key = Deno.env.get("GOOGLE_PLACES_API_KEY");
  if (!key) {
    return error(503, "PLACES_NOT_CONFIGURED", "Google place search is not set up yet.");
  }
  try {
    if (req.method === "GET") return await photo(req, url, key);
    if (req.method === "POST") return await search(req, key);
    return error(405, "METHOD_NOT_ALLOWED", "Use GET or POST.");
  } catch (cause) {
    console.error("places-search failed", String(cause));
    return error(502, "PLACES_FAILED", "Place search is unavailable right now.");
  }
});
