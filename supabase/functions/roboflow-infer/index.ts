// Runs NavAble's Roboflow accessibility detection on one photo.
//
// The app sends the signed-in user's access token and the photo as base64.
// The Roboflow API key stays here as the ROBOFLOW_API_KEY secret
// (Supabase dashboard > Edge Functions > Secrets), never in the app.
// Results are suggestions only; admins verify them in the admin app.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { runWorkflow, WorkflowError } from "./workflow.ts";

const maxBodyBytes = 1024 * 1024;
const maxImageBase64Chars = 960_000; // about 700 KiB of image data

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...corsHeaders },
  });
}

function error(status: number, code: string, message: string): Response {
  return json(status, { error: { code, message } });
}

// Confirms the caller is a signed-in NavAble user via Supabase Auth.
async function isSignedIn(req: Request, token: string): Promise<boolean> {
  const url = Deno.env.get("SUPABASE_URL");
  const apiKey = Deno.env.get("SUPABASE_ANON_KEY") ?? req.headers.get("apikey");
  if (!url || !apiKey) return false;
  const response = await fetch(`${url}/auth/v1/user`, {
    headers: { Authorization: `Bearer ${token}`, apikey: apiKey },
  });
  if (!response.ok) return false;
  const user = await response.json().catch(() => null);
  return typeof user?.id === "string" && user.id.length > 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return error(405, "METHOD_NOT_ALLOWED", "Use POST.");
  }

  const token = /^Bearer\s+(.+)$/i.exec(req.headers.get("Authorization") ?? "")
    ?.[1];
  if (!token || !(await isSignedIn(req, token))) {
    return error(
      401,
      "UNAUTHENTICATED",
      "Sign in before running image analysis.",
    );
  }

  const rawBody = await req.text();
  if (rawBody.length > maxBodyBytes) {
    return error(
      413,
      "IMAGE_TOO_LARGE",
      "Compress this photo to 700 KiB or less.",
    );
  }
  let imageBase64: unknown;
  try {
    imageBase64 = JSON.parse(rawBody)?.inputs?.image?.value;
  } catch {
    imageBase64 = undefined;
  }
  if (
    typeof imageBase64 !== "string" || !imageBase64 ||
    imageBase64.length > maxImageBase64Chars ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(imageBase64)
  ) {
    return error(
      400,
      "INVALID_IMAGE",
      "Attach one supported image no larger than 700 KiB.",
    );
  }

  const apiKey = Deno.env.get("ROBOFLOW_API_KEY");
  if (!apiKey) {
    return error(
      503,
      "INFERENCE_NOT_CONFIGURED",
      "Roboflow inference is not configured yet.",
    );
  }

  try {
    // Only the validated image is forwarded, never other client fields.
    const workflowBody = JSON.stringify({
      inputs: { image: { type: "base64", value: imageBase64 } },
    });
    return json(200, await runWorkflow(workflowBody, apiKey));
  } catch (cause) {
    const code = cause instanceof WorkflowError ? cause.code : "WORKFLOW_FAILED";
    console.error("roboflow-infer failed", code, String(cause));
    return error(
      502,
      code,
      "Roboflow could not analyze this photo. You can still submit it for review.",
    );
  }
});
