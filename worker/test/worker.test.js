import test from 'node:test';
import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import { handleRequest } from '../src/index.js';
import { verifyFirebaseIdToken } from '../src/firebase_auth.js';
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
  }), { FIREBASE_PROJECT_ID: 'project', ROBOFLOW_API_KEY: 'server-secret' }, {
    verifyToken: async (token, project) => {
      assert.equal(token, 'user-token');
      assert.equal(project, 'project');
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
  const env = { FIREBASE_PROJECT_ID: 'project', ROBOFLOW_API_KEY: 'test-secret' };
  const noAuth = await handleRequest(new Request('https://worker.test/infer', { method: 'POST' }), env);
  assert.equal(noAuth.status, 401);
  const urlImage = await handleRequest(new Request('https://worker.test/infer', {
    method: 'POST',
    headers: { Authorization: 'Bearer token', 'Content-Type': 'application/json' },
    body: JSON.stringify({ inputs: { image: { type: 'url', value: 'https://example.com/image.jpg' } } }),
  }), env, { verifyToken: async () => {} });
  assert.equal(urlImage.status, 400);
});

test('Firebase ID token verifier checks project claims and the RSA signature', async () => {
  const projectId = 'nav4ble-22f2d';
  const { privateKey, publicKey } = await webcrypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['sign', 'verify'],
  );
  const jwk = await webcrypto.subtle.exportKey('jwk', publicKey);
  jwk.kid = 'worker-test-key';
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  const header = encode({ alg: 'RS256', kid: jwk.kid, typ: 'JWT' });
  const now = Math.floor(Date.now() / 1000);
  const payload = encode({
    aud: projectId,
    iss: `https://securetoken.google.com/${projectId}`,
    sub: 'test-user',
    iat: now,
    exp: now + 300,
  });
  const message = `${header}.${payload}`;
  const signature = await webcrypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(message),
  );
  const token = `${message}.${Buffer.from(signature).toString('base64url')}`;
  const fetchImpl = async () => new Response(JSON.stringify({ keys: [jwk] }), {
    headers: { 'Cache-Control': 'public, max-age=300' },
  });

  const verified = await verifyFirebaseIdToken(token, projectId, fetchImpl);
  assert.equal(verified.uid, 'test-user');
  await assert.rejects(() => verifyFirebaseIdToken(token, 'wrong-project', fetchImpl));
  const tampered = `${message}.${Buffer.from(new Uint8Array(256)).toString('base64url')}`;
  await assert.rejects(() => verifyFirebaseIdToken(tampered, projectId, fetchImpl));
});
