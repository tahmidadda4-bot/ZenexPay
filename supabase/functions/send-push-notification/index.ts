import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'https://esm.sh/jose@5.9.6';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

async function googleAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const key = await importPKCS8(serviceAccount.private_key, 'RS256');
  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });

  if (!response.ok) {
    throw new Error(`Google OAuth failed: ${await response.text()}`);
  }
  const json = await response.json();
  return json.access_token;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    const payload = await req.json();
    const record = payload.record ?? payload;

    const userId = record.user_id;
    const title = record.title ?? 'ZenexPay';
    const body = record.body ?? 'You have a new update.';
    const data = {
      notification_id: String(record.id ?? ''),
      type: String(record.type ?? 'general'),
      ...(typeof record.data === 'object' && record.data ? record.data : {}),
    };

    if (!userId) {
      return new Response(JSON.stringify({ ok: false, error: 'Missing user_id' }), {
        status: 400,
        headers: { 'content-type': 'application/json' },
      });
    }

    const { data: tokens, error } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('user_id', userId);

    if (error) throw error;

    const serviceAccountText = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountText) {
      throw new Error('Missing FIREBASE_SERVICE_ACCOUNT_JSON secret');
    }
    const serviceAccount = JSON.parse(serviceAccountText);
    const accessToken = await googleAccessToken(serviceAccount);

    const results = [];
    for (const row of tokens ?? []) {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: row.token,
              notification: { title, body },
              data: Object.fromEntries(
                Object.entries(data).map(([k, v]) => [k, String(v)]),
              ),
              android: {
                priority: 'HIGH',
                notification: {
                  channel_id: 'zenexpay_high_importance',
                  sound: 'default',
                },
              },
            },
          }),
        },
      );

      results.push({ token: row.token, ok: response.ok, status: response.status });

      if (!response.ok) {
        const text = await response.text();
        // Remove stale tokens when FCM says the registration token is invalid.
        if (text.includes('UNREGISTERED') || text.includes('registration-token-not-registered')) {
          await supabase.from('device_tokens').delete().eq('token', row.token);
        }
      }
    }

    return new Response(JSON.stringify({ ok: true, sent: results.length, results }), {
      headers: { 'content-type': 'application/json' },
    });
  } catch (error) {
    return new Response(
      JSON.stringify({ ok: false, error: error instanceof Error ? error.message : String(error) }),
      { status: 500, headers: { 'content-type': 'application/json' } },
    );
  }
});
