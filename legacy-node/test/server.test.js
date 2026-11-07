const crypto = require('crypto'), fs = require('fs');
const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 });
fs.writeFileSync('' + require('os').tmpdir() + '/sa.json', JSON.stringify({ client_email: 'sa@x.iam.gserviceaccount.com', private_key: privateKey.export({ type: 'pkcs8', format: 'pem' }) }));
process.env.GOOGLE_KEY_FILE = '' + require('os').tmpdir() + '/sa.json';
process.env.TZ = 'Europe/Copenhagen';

const day = new Date(); day.setHours(0,0,0,0);
const at = (h, m = 0) => new Date(day.getTime() + (h * 60 + m) * 60000).toISOString();
const ymd = day.toISOString().slice(0, 10);

const cal = {
  'jakob@example.com': [
    { id: '1', iCalUID: 'u1', summary: 'Dinner', start: { dateTime: at(19) }, end: { dateTime: at(21) },
      attendees: [{ email: 'mette@example.com', responseStatus: 'accepted' }] },
    { id: '2', iCalUID: 'u2', summary: 'Gone', status: 'cancelled', start: { dateTime: at(9) }, end: { dateTime: at(10) } },
    { id: '3', iCalUID: 'u3', summary: 'Trip', start: { date: ymd }, end: { date: ymd } },
  ],
  'mette@example.com': [
    { id: '1b', iCalUID: 'u1', summary: 'Dinner', start: { dateTime: at(19) }, end: { dateTime: at(21) } },
    { id: '4', iCalUID: 'u4', summary: 'Declined thing', start: { dateTime: at(12) }, end: { dateTime: at(13) },
      attendees: [{ email: 'mette@example.com', responseStatus: 'declined' }] },
  ],
  'family@group.calendar.google.com': [
    { id: '5', iCalUID: 'u5', summary: 'Nobody', start: { dateTime: at(15) }, end: { dateTime: at(16) } },
    { id: '6', iCalUID: 'u6', summary: 'Kids', start: { dateTime: at(16) }, end: { dateTime: at(17) },
      attendees: [{ email: 'jakob@example.com' }] },
  ],
};
const quarter = [];
for (let h = 0; h < 72; h++) for (let q = 0; q < 4; q++) {
  const t = new Date(day.getTime() - 3600e3 + (h * 60 + q * 15) * 60000);   // UTC-ish stamps, no Z
  quarter.push({ TimeUTC: t.toISOString().slice(0, 19), PriceArea: 'DK2', DayAheadPriceDKK: 400 + h * 10 + q * 20, DayAheadPriceEUR: 50 });
}
let calls = [];
global.fetch = async (url, opts) => {
  url = String(url); calls.push(url.split('?')[0]);
  const ok = (j) => ({ ok: true, status: 200, json: async () => j });
  if (url.startsWith('https://oauth2.googleapis.com/token')) {
    const body = new URLSearchParams(opts.body).get('assertion').split('.');
    const v = crypto.createVerify('RSA-SHA256').update(body[0] + '.' + body[1]).verify(publicKey, body[2], 'base64url');
    if (!v) return { ok: false, status: 401 };
    return ok({ access_token: 'tok', expires_in: 3600 });
  }
  if (url.includes('googleapis.com/calendar')) {
    if (opts.headers.authorization !== 'Bearer tok') return { ok: false, status: 401 };
    const id = decodeURIComponent(url.split('/calendars/')[1].split('/events')[0]);
    return ok({ items: cal[id] });
  }
  if (url.includes('energidataservice')) return ok({ records: quarter });
  if (url.includes('open-meteo')) return ok({ ok: 1, url });
  throw new Error('unexpected ' + url);
};
const s = require('../server.js');
(async () => {
  const ev = await s.events();
  console.log(ev.map((e) => `${e.title}${e.allDay ? ' [all-day]' : ''}: ${e.who.map((w) => w.initial).join('')}`));
  const pr = await s.prices();
  console.log('hours', pr.length, 'first', pr[0], new Date(pr[0].t).toISOString());
  console.log('weather', (await s.weather()).url.slice(0, 200));
})().catch((e) => { console.error('FAIL', e); process.exit(1); });
