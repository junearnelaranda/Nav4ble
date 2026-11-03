import { verifySupabaseAccessToken } from './supabase_auth.js';
import { runWorkflowForImage, WorkflowError } from './workflow.js';

const maxBodyBytes = 1024 * 1024;
const maxImageBase64Chars = 960_000;
const workflowBodyPrefix = '{"inputs":{"image":{"type":"base64","value":"';
const workflowBodySuffix = '"}}}';

function json(status, body, corsHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...corsHeaders },
  });
}

function cors(request) {
  const origin = request.headers.get('Origin');
  return {
    'Access-Control-Allow-Origin': origin || '*',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  };
}

function bearerToken(request) {
  const match = /^Bearer\s+(.+)$/i.exec(request.headers.get('Authorization') || '');
  return match?.[1] || null;
}

export async function handleRequest(request, env, dependencies = {}) {
  const headers = cors(request);
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers });
  if (request.method !== 'POST' || new URL(request.url).pathname !== '/infer') {
    return json(404, { error: { code: 'NOT_FOUND', message: 'Route not found.' } }, headers);
  }
  const token = bearerToken(request);
  if (!token) {
    return json(401, { error: { code: 'UNAUTHENTICATED', message: 'Sign in before running image analysis.' } }, headers);
  }
  if (!env.SUPABASE_URL || !env.SUPABASE_PUBLISHABLE_KEY) {
    return json(503, { error: { code: 'AUTH_NOT_CONFIGURED', message: 'Supabase authentication is not configured yet.' } }, headers);
  }
  try {
    await (dependencies.verifyToken || verifySupabaseAccessToken)(
      token,
      env.SUPABASE_URL,
      env.SUPABASE_PUBLISHABLE_KEY,
      dependencies.fetchImpl || fetch,
    );
  } catch (_) {
    return json(401, { error: { code: 'UNAUTHENTICATED', message: 'Supabase sign-in token is invalid or expired.' } }, headers);
  }

  const declaredLength = Number(request.headers.get('Content-Length') || 0);
  if (declaredLength > maxBodyBytes) {
    return json(413, { error: { code: 'IMAGE_TOO_LARGE', message: 'Compress this photo to 700 KiB or less.' } }, headers);
  }
  let rawBody;
  try {
    rawBody = await readRequestBody(request, maxBodyBytes);
  } catch (_) {
    return json(413, { error: { code: 'IMAGE_TOO_LARGE', message: 'Compress this photo to 700 KiB or less.' } }, headers);
  }
  if (!rawBody.startsWith(workflowBodyPrefix) || !rawBody.endsWith(workflowBodySuffix)) {
    return json(400, { error: { code: 'INVALID_IMAGE', message: 'Attach one supported image no larger than 700 KiB.' } }, headers);
  }
  const imageBase64 = rawBody.slice(workflowBodyPrefix.length, -workflowBodySuffix.length);
  if (!imageBase64 || imageBase64.length > maxImageBase64Chars || !/^[A-Za-z0-9+/]+={0,2}$/.test(imageBase64)) {
    return json(400, { error: { code: 'INVALID_IMAGE', message: 'Attach one supported image no larger than 700 KiB.' } }, headers);
  }
  if (!env.ROBOFLOW_API_KEY) {
    return json(503, { error: { code: 'INFERENCE_NOT_CONFIGURED', message: 'Roboflow inference is not configured yet.' } }, headers);
  }

  try {
    const result = await (dependencies.runWorkflow || runWorkflowForImage)({
      imageBase64,
      workflowBody: rawBody,
      apiKey: env.ROBOFLOW_API_KEY,
      fetchImpl: dependencies.workflowFetch || fetch,
    });
    return json(200, result, headers);
  } catch (error) {
    const code = error instanceof WorkflowError ? error.code : 'WORKFLOW_FAILED';
    return json(502, { error: { code, message: 'Roboflow could not analyze this photo. You can still submit it for review.' } }, headers);
  }
}

async function readRequestBody(request, limit) {
  if (!request.body) throw new Error('missing-body');
  const reader = request.body.getReader();
  const chunks = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > limit) {
      await reader.cancel();
      throw new Error('body-too-large');
    }
    chunks.push(value);
  }
  if (chunks.length === 1) return new TextDecoder().decode(chunks[0]);
  const allBytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    allBytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(allBytes);
}

export default {
  fetch(request, env) {
    return handleRequest(request, env);
  },
};
