import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

const url = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const secret = Deno.env.get('WEBHOOK_SECRET')!;
webpush.setVapidDetails(Deno.env.get('VAPID_CONTACT')!, Deno.env.get('VAPID_PUBLIC_KEY')!, Deno.env.get('VAPID_PRIVATE_KEY')!);
const db = createClient(url, serviceKey);

Deno.serve(async request => {
  if (request.method !== 'POST' || !secret || request.headers.get('x-webhook-secret') !== secret)
    return new Response('Unauthorized', { status: 401 });
  try {
    const event = await request.json();
    if (event.type !== 'INSERT' || event.table !== 'notifications' || !event.record?.id)
      return new Response('Ignored', { status: 200 });
    const { data: notice, error: findError } = await db.from('notifications').select('id,recipient_id,body').eq('id', event.record.id).single();
    if (findError || !notice) return new Response('Not found', { status: 404 });
    const { data: devices, error } = await db.from('push_subscriptions').select('endpoint,subscription').eq('user_id', notice.recipient_id);
    if (error) throw error;
    const payload = JSON.stringify({ title: 'Casa a Punto', body: notice.body, tag: notice.id, url: './' });
    const results = await Promise.allSettled((devices || []).map(async device => {
      try { await webpush.sendNotification(device.subscription, payload); }
      catch (e) {
        if ((e as { statusCode?: number })?.statusCode === 404 || (e as { statusCode?: number })?.statusCode === 410)
          await db.from('push_subscriptions').delete().eq('endpoint', device.endpoint);
        else throw e;
      }
    }));
    if (results.some(result => result.status === 'rejected')) throw new Error('At least one delivery failed');
    return new Response('Sent', { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response('Delivery error', { status: 500 });
  }
});
