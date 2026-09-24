import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { importPKCS8, SignJWT } from 'https://esm.sh/jose@5.9.6';

const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
);

async function googleAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const key = await importPKCS8(
    serviceAccount.private_key,
    'RS256',
  );

  const assertion = await new SignJWT({
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  })
    .setProtectedHeader({
      alg: 'RS256',
      typ: 'JWT',
    })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const response = await fetch(
    'https://oauth2.googleapis.com/token',
    {
      method: 'POST',
      headers: {
        'content-type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type:
            'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
    },
  );

  const responseText = await response.text();

  if (!response.ok) {
    throw new Error(
      `Google OAuth failed (${response.status}): ${responseText}`,
    );
  }

  const json = JSON.parse(responseText);

  if (!json.access_token) {
    throw new Error(
      `Google OAuth returned no access token: ${responseText}`,
    );
  }

  return json.access_token;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== 'POST') {
      return new Response(
        JSON.stringify({
          ok: false,
          error: 'Method not allowed',
        }),
        {
          status: 405,
          headers: {
            'content-type': 'application/json',
          },
        },
      );
    }

    const payload = await req.json();

    console.log(
      'Webhook payload:',
      JSON.stringify(payload),
    );

    const record = payload.record ?? payload;

    const userId = record.user_id;

    const title = record.title ?? 'ZenexPay';

    // IMPORTANT:
    // notifications table uses "message", not "body".
    const body =
      record.message ??
      record.body ??
      'You have a new update.';

    const data = {
      notification_id: String(record.id ?? ''),
      type: String(record.type ?? 'general'),
      ...(typeof record.data === 'object' && record.data
        ? record.data
        : {}),
    };

    if (!userId) {
      throw new Error('Missing user_id in notification record');
    }

    console.log('User ID:', userId);
    console.log('Title:', title);
    console.log('Body:', body);

    const {
      data: tokens,
      error: tokenError,
    } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('user_id', userId);

    if (tokenError) {
      throw new Error(
        `Device token query failed: ${tokenError.message}`,
      );
    }

    console.log(
      'Device token count:',
      tokens?.length ?? 0,
    );

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({
          ok: true,
          sent: 0,
          message: 'No device tokens found for this user.',
        }),
        {
          headers: {
            'content-type': 'application/json',
          },
        },
      );
    }

    const serviceAccountText = Deno.env.get(
      'FIREBASE_SERVICE_ACCOUNT_JSON',
    );

    if (!serviceAccountText) {
      throw new Error(
        'Missing FIREBASE_SERVICE_ACCOUNT_JSON secret',
      );
    }

    let serviceAccount: any;

    try {
      serviceAccount = JSON.parse(serviceAccountText);
    } catch (e) {
      throw new Error(
        `FIREBASE_SERVICE_ACCOUNT_JSON is not valid JSON: ${e}`,
      );
    }

    if (!serviceAccount.project_id) {
      throw new Error(
        'Firebase service account is missing project_id',
      );
    }

    if (!serviceAccount.client_email) {
      throw new Error(
        'Firebase service account is missing client_email',
      );
    }

    if (!serviceAccount.private_key) {
      throw new Error(
        'Firebase service account is missing private_key',
      );
    }

    console.log(
      'Firebase project:',
      serviceAccount.project_id,
    );

    const accessToken =
      await googleAccessToken(serviceAccount);

    console.log('Google access token obtained successfully');

    const results = [];

    for (const row of tokens) {
      try {
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

                notification: {
                  title: title,
                  body: body,
                },

                data: Object.fromEntries(
                  Object.entries(data).map(
                    ([key, value]) => [
                      key,
                      String(value),
                    ],
                  ),
                ),

                android: {
                  priority: 'HIGH',
                  notification: {
                    channel_id:
                      'zenexpay_high_importance',
                    sound: 'default',
                  },
                },
              },
            }),
          },
        );

        const responseText = await response.text();

        console.log(
          'FCM response:',
          response.status,
          responseText,
        );

        results.push({
          token: row.token,
          ok: response.ok,
          status: response.status,
          response: responseText,
        });

        if (
          !response.ok &&
          (
            responseText.includes('UNREGISTERED') ||
            responseText.includes(
              'registration-token-not-registered',
            )
          )
        ) {
          await supabase
            .from('device_tokens')
            .delete()
            .eq('token', row.token);
        }
      } catch (e) {
        results.push({
          token: row.token,
          ok: false,
          error: String(e),
        });
      }
    }

    return new Response(
      JSON.stringify({
        ok: true,
        sent: results.filter((r) => r.ok).length,
        total: results.length,
        results,
      }),
      {
        headers: {
          'content-type': 'application/json',
        },
      },
    );
  } catch (error) {
    console.error('PUSH FUNCTION ERROR:', error);

    return new Response(
      JSON.stringify({
        ok: false,
        error:
          error instanceof Error
            ? error.message
            : String(error),
      }),
      {
        status: 500,
        headers: {
          'content-type': 'application/json',
        },
      },
    );
  }
});
