// Google Places search for the NavAble Explore tab.
//
//   POST {query, latitude?, longitude?}  -> {places: [...]} (Text Search, New)
//   GET  ?photo=<photo name>&w=<px>       -> redirect to the photo image
//
// The Google key stays here as the GOOGLE_PLACES_API_KEY secret
// (Supabase dashboard > Edge Functions > Secrets), never in the app.
// Google's terms: results are shown live with Google attribution; NavAble
// stores only the place id, and they must not be drawn on a non-Google map.

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

async function photo(url: URL, key: string): Promise<Response> {
  const name = url.searchParams.get("photo") ?? "";
  const width = Math.min(Math.max(Number(url.searchParams.get("w")) || 600, 100), 1200);
  if (!PHOTO_NAME.test(name)) {
    return error(400, "INVALID_PHOTO", "Unknown photo.");
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
    if (req.method === "GET") return await photo(url, key);
    if (req.method === "POST") return await search(req, key);
    return error(405, "METHOD_NOT_ALLOWED", "Use GET or POST.");
  } catch (cause) {
    console.error("places-search failed", String(cause));
    return error(502, "PLACES_FAILED", "Place search is unavailable right now.");
  }
});
