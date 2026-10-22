let cachedKeySet;
let cachedKeySetExpiresAt = 0;
const FIREBASE_CERTS_URL =
  'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

function decodeBase64Url(segment) {
  const normalized = segment.replace(/-/g, '+').replace(/_/g, '/');
  const binary = atob(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '='));
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function getSigningKey(kid, fetchImpl) {
  if (!cachedKeySet || Date.now() >= cachedKeySetExpiresAt) {
    const response = await fetchImpl(FIREBASE_CERTS_URL);
    if (!response.ok) throw new Error('Could not retrieve Firebase signing keys.');
    cachedKeySet = await response.json();
    const maxAge = Number(/max-age=(\d+)/i.exec(response.headers.get('cache-control') || '')?.[1] || 300);
    cachedKeySetExpiresAt = Date.now() + Math.max(60, maxAge) * 1000;
  }
  const jwk = cachedKeySet.keys?.find((key) => key.kid === kid && key.kty === 'RSA');
  if (!jwk) {
    cachedKeySet = undefined;
    cachedKeySetExpiresAt = 0;
    throw new Error('Firebase token signing key was not found.');
  }
  return crypto.subtle.importKey(
    'jwk',
    jwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
}

export async function verifyFirebaseIdToken(token, projectId, fetchImpl = fetch) {
  if (typeof token !== 'string' || token.length > 8192) throw new Error('Invalid Firebase ID token.');
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Invalid Firebase ID token.');
  let header;
  let claims;
  try {
    header = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[0])));
    claims = JSON.parse(new TextDecoder().decode(decodeBase64Url(parts[1])));
  } catch (_) {
    throw new Error('Invalid Firebase ID token.');
  }
  if (header.alg !== 'RS256' || typeof header.kid !== 'string') {
    throw new Error('Unsupported Firebase ID token.');
  }
  const now = Math.floor(Date.now() / 1000);
  if (
    claims.aud !== projectId ||
    claims.iss !== `https://securetoken.google.com/${projectId}` ||
    typeof claims.sub !== 'string' || claims.sub.length < 1 || claims.sub.length > 128 ||
    !Number.isFinite(claims.exp) || claims.exp <= now ||
    !Number.isFinite(claims.iat) || claims.iat > now + 60
  ) {
    throw new Error('Firebase ID token is invalid or expired.');
  }

  const key = await getSigningKey(header.kid, fetchImpl);
  const signedData = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
  const signature = decodeBase64Url(parts[2]);
  const verified = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    signature,
    signedData,
  );
  if (!verified) throw new Error('Firebase ID token signature is invalid.');
  return { uid: claims.sub, claims };
}
