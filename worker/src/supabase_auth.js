export async function verifySupabaseAccessToken(
  token,
  supabaseUrl,
  publishableKey,
  fetchImpl = fetch,
) {
  if (typeof token !== 'string' || !token || token.length > 8192) {
    throw new Error('Invalid access token.');
  }
  if (!supabaseUrl || !publishableKey) {
    throw new Error('Supabase authentication is not configured.');
  }
  const base = new URL(supabaseUrl);
  if (base.protocol !== 'https:') throw new Error('Supabase URL must use HTTPS.');
  const response = await fetchImpl(new URL('/auth/v1/user', base), {
    headers: {
      apikey: publishableKey,
      Authorization: `Bearer ${token}`,
    },
  });
  if (!response.ok) throw new Error('Access token is invalid or expired.');
  const user = await response.json();
  if (!user || typeof user.id !== 'string' || !user.id) {
    throw new Error('Supabase user response is invalid.');
  }
  return user;
}
