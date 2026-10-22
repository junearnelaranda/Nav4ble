import { readFile } from 'node:fs/promises';

const workerUrl = process.env.NAVABLE_WORKER_URL?.replace(/\/$/, '');
const firebaseToken = process.env.FIREBASE_ID_TOKEN;
const imagePath = process.argv[2];

if (!workerUrl || !firebaseToken || !imagePath) {
  console.error('Usage: set NAVABLE_WORKER_URL and FIREBASE_ID_TOKEN, then run: node scripts/smoke.js <sample-image>');
  process.exit(2);
}

const imageBytes = await readFile(imagePath);
if (imageBytes.byteLength > 700 * 1024) {
  console.error('Sample image must be 700 KiB or smaller.');
  process.exit(2);
}
const imageBase64 = imageBytes.toString('base64');
const response = await fetch(`${workerUrl}/infer`, {
  method: 'POST',
  headers: {
    Authorization: `Bearer ${firebaseToken}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ inputs: { image: { type: 'base64', value: imageBase64 } } }),
  signal: AbortSignal.timeout(90_000),
});

const result = await response.json().catch(() => null);
if (!response.ok) {
  const message = result?.error?.message || `Worker returned HTTP ${response.status}.`;
  console.error(message);
  process.exit(1);
}
if (
  !result ||
  typeof result.image !== 'object' ||
  !Array.isArray(result.detections)
) {
  console.error('Smoke test failed: response must include image metadata and a detections array.');
  process.exit(1);
}

console.log(`Smoke test passed (${result.detections.length} detections).`);
