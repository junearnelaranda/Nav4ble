import test from 'node:test';
import assert from 'node:assert/strict';
import { handleRequest } from '../src/index.js';
import { verifySupabaseAccessToken } from '../src/supabase_auth.js';
import { parseWorkflowResponse, runWorkflowForImage } from '../src/workflow.js';

const realShape = {
  predictions: { image: { width: null, height: null }, predictions: [] },
};

test('workflow parser follows the verified predictions output and omits image data', () => {
  assert.deepEqual(parseWorkflowResponse([realShape]), {
    image: { width: null, height: null },
    detections: [],
  });
  assert.deepEqual(
    parseWorkflowResponse({ predictions: { image: { width: 640, height: 480 }, predictions: [
      { label: 'ramp', confidence: 0.94, points: [{ x: 1, y: 2 }] },
    ] } }).detections,
    [{ label: 'ramp', confidence: 0.94 }],
  );
});

test('workflow uses header auth and base64 image input without runtime parameters', async () => {
  let seen;
  await runWorkflowForImage({
    imageBase64: 'ZmFrZQ==',
    apiKey: 'test-key',
    fetchImpl: async (url, options) => {
      seen = { url, options };
      return { ok: true, json: async () => realShape };
    },
  });
  assert.match(seen.url, /nav-able\/workflows\/navable-accessibility-detection-/);
  assert.equal(seen.options.headers.Authorization, 'Bearer test-key');
  assert.deepEqual(JSON.parse(seen.options.body), {
    inputs: { image: { type: 'base64', value: 'ZmFrZQ==' } },
  });
});

test('worker authenticates users, validates a small base64 payload, then runs inference', async () => {
  let inferenceInput;
  const response = await handleRequest(new Request('https://worker.test/infer', {
    method: 'POST',
    headers: { Authorization: 'Bearer user-token', 'Content-Type': 'application/json' },
    body: JSON.stringify({ inputs: { image: { type: 'base64', value: 'ZmFrZQ==' } } }),
  }), { SUPABASE_URL: 'https://project.supabase.co', SUPABASE_PUBLISHABLE_KEY: 'publishable', ROBOFLOW_API_KEY: 'server-secret' }, {
    verifyToken: async (token, url, key) => {
      assert.equal(token, 'user-token');
      assert.equal(url, 'https://project.supabase.co');
      assert.equal(key, 'publishable');
    },
    runWorkflow: async (args) => {
      inferenceInput = args;
      return { image: { width: null, height: null }, detections: [] };
    },
  });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { image: { width: null, height: null }, detections: [] });
  assert.equal(inferenceInput.imageBase64, 'ZmFrZQ==');
  assert.equal(inferenceInput.apiKey, 'server-secret');
});

test('worker rejects missing auth and URL inputs', async () => {
  const env = { SUPABASE_URL: 'https://project.supabase.co', SUPABASE_PUBLISHABLE_KEY: 'publishable', ROBOFLOW_API_KEY: 'test-secret' };
  const noAuth = await handleRequest(new Request('https://worker.test/infer', { method: 'POST' }), env);
  assert.equal(noAuth.status, 401);
  const urlImage = await handleRequest(new Request('https://worker.test/infer', {
    method: 'POST',
    headers: { Authorization: 'Bearer token', 'Content-Type': 'application/json' },
    body: JSON.stringify({ inputs: { image: { type: 'url', value: 'https://example.com/image.jpg' } } }),
  }), env, { verifyToken: async () => {} });
  assert.equal(urlImage.status, 400);
});

test('Supabase access token verifier uses Auth user endpoint and rejects invalid tokens', async () => {
  let seen;
  const fetchImpl = async (url, options) => {
    seen = { url: url.toString(), options };
    return new Response(JSON.stringify({ id: 'test-user' }), { status: 200 });
  };
  const user = await verifySupabaseAccessToken('user-token', 'https://project.supabase.co', 'publishable', fetchImpl);
  assert.equal(user.id, 'test-user');
  assert.equal(seen.url, 'https://project.supabase.co/auth/v1/user');
  assert.equal(seen.options.headers.apikey, 'publishable');
  assert.equal(seen.options.headers.Authorization, 'Bearer user-token');
  await assert.rejects(() => verifySupabaseAccessToken('bad-token', 'https://project.supabase.co', 'publishable',
    async () => new Response('{}', { status: 401 })));
  await assert.rejects(() => verifySupabaseAccessToken('user-token', 'http://project.supabase.co', 'publishable', fetchImpl));
});
