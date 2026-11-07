// Kitchen dashboard server. Node 18+, no dependencies.
//
//   GOOGLE_KEY_FILE=./service-account.json node server.js     (default port 8080)
//
// Serves index.html and three cached JSON endpoints: /api/events, /api/weather, /api/prices.
// Calendar access uses a Google service account: create one, download its JSON key, and share
// each calendar with the service account's email address ("See all event details").

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

process.env.TZ = process.env.TZ || 'Europe/Copenhagen';

// ---- config ---------------------------------------------------------------

const LAT = 55.68, LON = 12.57;   // home, used for the weather (this is Copenhagen: change it)
const PRICE_AREA = 'DK2';         // DK1 = west of Storebælt, DK2 = east

// Spot price (kr/kWh, ex VAT) -> what you pay. Add your net tariff + supplier markup here.
// Example with a peak tariff: (d) => (d.getHours() >= 17 && d.getHours() < 21 ? 0.6 : 0.25)
const extra = (d) => 0;
const VAT = 1.25;

// One entry per family member. The key is the initial shown in the avatar.
const PEOPLE = {
  J: { color: '#7FA4FF', emails: ['jakob@example.com'] },
  M: { color: '#FF9B63', emails: ['mette@example.com'] },
  A: { color: '#4FD1B0', emails: [] },
  I: { color: '#C79BFF', emails: [] },
};

// Calendars to read. `who` = people an event on that calendar belongs to by default.
// Invitees found in an event's attendee list (matched by PEOPLE.emails) are added, and
// anyone who declined is removed. A shared family calendar can use who: '' and rely on attendees.
const CALENDARS = [
  { id: 'jakob@example.com', who: 'J' },
  { id: 'mette@example.com', who: 'M' },
  { id: 'family@group.calendar.google.com', who: '' },
];

// ---- helpers --------------------------------------------------------------

const cache = {};
async function cached(key, ttl, fn) {
  const c = cache[key];
  if (c && Date.now() - c.t < ttl) return c.v;
  try {
    const v = await fn();
    cache[key] = { t: Date.now(), v };
    return v;
  } catch (e) {
    if (c) return c.v; // serve stale rather than blank the display
    throw e;
  }
}

async function getJson(url, opts) {
  const r = await fetch(url, opts);
  if (!r.ok) throw new Error(`${url.split('?')[0]} -> ${r.status}`);
  return r.json();
}

// ---- Google Calendar ------------------------------------------------------

let tok = { v: null, exp: 0 };
async function token() {
  if (tok.exp > Date.now() + 60e3) return tok.v;
  const key = JSON.parse(fs.readFileSync(process.env.GOOGLE_KEY_FILE || './service-account.json', 'utf8'));
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const unsigned = b64({ alg: 'RS256', typ: 'JWT' }) + '.' + b64({
    iss: key.client_email,
    scope: 'https://www.googleapis.com/auth/calendar.readonly',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  });
  const sig = crypto.createSign('RSA-SHA256').update(unsigned).sign(key.private_key, 'base64url');
  const j = await getJson('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: unsigned + '.' + sig,
    }),
  });
  tok = { v: j.access_token, exp: Date.now() + j.expires_in * 1000 };
  return tok.v;
}

async function events() {
  const bearer = 'Bearer ' + (await token());
  const from = new Date();
  from.setHours(0, 0, 0, 0);
  const to = new Date(Date.now() + 16 * 36e5);
  const seen = new Map();

  await Promise.all(CALENDARS.map(async (cal) => {
    const q = new URLSearchParams({
      singleEvents: 'true', // expands recurring events
      orderBy: 'startTime',
      maxResults: '100',
      timeMin: from.toISOString(),
      timeMax: to.toISOString(),
    });
    const url = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(cal.id)}/events?${q}`;
    const { items = [] } = await getJson(url, { headers: { authorization: bearer } });

    for (const e of items) {
      if (e.status === 'cancelled') continue;
      const yes = new Set(cal.who), no = new Set();
      for (const a of e.attendees || []) {
        const p = Object.keys(PEOPLE).find((k) => PEOPLE[k].emails.includes(a.email));
        if (!p) continue;
        if (a.responseStatus === 'declined') no.add(p); else yes.add(p);
      }
      const start = e.start.dateTime || e.start.date;
      const end = e.end.dateTime || e.end.date;
      const key = (e.iCalUID || e.id) + '|' + start; // same event seen on several calendars
      const prev = seen.get(key);
      if (prev) {
        yes.forEach((p) => prev.yes.add(p));
        no.forEach((p) => prev.no.add(p));
      } else {
        seen.set(key, { title: e.summary || '(no title)', location: e.location || '', start, end, allDay: !!e.start.date, yes, no });
      }
    }
  }));

  const order = Object.keys(PEOPLE);
  return [...seen.values()]
    .map(({ yes, no, ...e }) => ({
      ...e,
      who: order.filter((p) => yes.has(p) && !no.has(p)).map((p) => ({ initial: p, color: PEOPLE[p].color })),
    }))
    .filter((e) => e.who.length);
}

// ---- weather (Open-Meteo) -------------------------------------------------

function weather() {
  const q = new URLSearchParams({
    latitude: LAT, longitude: LON, timezone: 'auto', wind_speed_unit: 'ms', forecast_days: 2,
    current: 'temperature_2m,apparent_temperature,weather_code,wind_speed_10m,wind_direction_10m',
    hourly: 'precipitation,uv_index,wind_speed_10m,wind_gusts_10m,is_day,weather_code',
  });
  return getJson('https://api.open-meteo.com/v1/forecast?' + q);
}

// ---- electricity prices (Energi Data Service, day-ahead, 15-min -> hourly) -

async function prices() {
  const day = (n) => {
    const d = new Date();
    d.setHours(0, 0, 0, 0);
    d.setDate(d.getDate() + n);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  };
  const q = new URLSearchParams({
    start: day(0), end: day(3), // end is exclusive
    filter: JSON.stringify({ PriceArea: [PRICE_AREA] }),
    sort: 'TimeUTC asc',
    limit: '400',
  });
  const { records = [] } = await getJson('https://api.energidataservice.dk/dataset/DayAheadPrices?' + q);

  const hours = new Map();
  for (const r of records) {
    if (r.DayAheadPriceDKK == null) continue;
    const utc = /Z$/.test(r.TimeUTC) ? r.TimeUTC : r.TimeUTC + 'Z';
    const t = Math.floor(Date.parse(utc) / 36e5) * 36e5;
    const h = hours.get(t) || { sum: 0, n: 0 };
    h.sum += r.DayAheadPriceDKK / 1000; // DKK/MWh -> kr/kWh
    h.n++;
    hours.set(t, h);
  }
  return [...hours].map(([t, h]) => ({ t, p: (h.sum / h.n + extra(new Date(t))) * VAT }));
}

// ---- server ---------------------------------------------------------------

const routes = {
  '/api/events': () => cached('events', 5 * 60e3, events),
  '/api/weather': () => cached('weather', 10 * 60e3, weather),
  '/api/prices': () => cached('prices', 30 * 60e3, prices),
};

const server = http.createServer(async (req, res) => {
  const { pathname } = new URL(req.url, 'http://localhost');
  try {
    if (routes[pathname]) {
      res.writeHead(200, { 'content-type': 'application/json' });
      return res.end(JSON.stringify(await routes[pathname]()));
    }
    if (pathname === '/' || pathname === '/index.html') {
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      return res.end(fs.readFileSync(path.join(__dirname, 'index.html')));
    }
    res.writeHead(404).end();
  } catch (e) {
    console.error(pathname, e.message);
    res.writeHead(502).end(e.message);
  }
});

if (require.main === module) {
  server.listen(process.env.PORT || 8080, process.env.HOST || '0.0.0.0', () => console.log('http://localhost:' + (process.env.PORT || 8080)));
}

module.exports = { events, weather, prices, token };
