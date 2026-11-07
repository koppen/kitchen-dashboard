process.env.TZ = 'Europe/Copenhagen';
const { JSDOM } = require('jsdom'); const fs = require('fs');
const html = fs.readFileSync(require('path').join(__dirname, '../index.html'), 'utf8').replace(/<link[^>]*>/, '');
const pad = (n) => String(n).padStart(2, '0');
const now = new Date(); const H = 36e5;
const start = new Date(now); start.setMinutes(0, 0, 0);
const day0 = new Date(now); day0.setHours(0, 0, 0, 0);
const local = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
const times = Array.from({ length: 48 }, (_, i) => local(new Date(day0.getTime() + i * H)));
const i0 = times.indexOf(local(start));
const arr = (f) => times.map((_, i) => f(i));
const weather = {
  current: { time: local(now), temperature_2m: 9.2, apparent_temperature: 6.4, weather_code: 3, wind_speed_10m: 6.8, wind_direction_10m: 320 },
  hourly: { time: times,
    precipitation: arr((i) => (i === i0 + 3 || i === i0 + 4 ? 0.9 : 0)),   // rain during hours i0+2, i0+3
    uv_index: arr((i) => (i === i0 || i === i0 + 1 ? 5.2 : 0)),
    wind_speed_10m: arr(() => 5), wind_gusts_10m: arr(() => 8), is_day: arr(() => 1), weather_code: arr(() => 3) },
};
const ev = (s, e, title, who, extra = {}) => ({ title, location: '', start: new Date(now.getTime() + s * H).toISOString(), end: new Date(now.getTime() + e * H).toISOString(), allDay: false, who: who.split('').map((c) => ({ initial: c, color: '#888' })), ...extra });
const today = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
const tomorrow = local(new Date(day0.getTime() + 36 * H)).slice(0, 10);
const events = [
  ev(-0.5, 1, 'Football', 'A', { location: 'Hallen' }),
  ev(1.2, 3.7, 'Dinner at Mormor', 'JAI'),
  ev(2.2, 4, 'Book club', 'M'),
  ev(-3, -2, 'Already over', 'J'),
  { title: 'School trip', location: '', start: today, end: tomorrow, allDay: true, who: [{ initial: 'I', color: '#c79bff' }] },
];
const prices = Array.from({ length: 48 }, (_, i) => ({ t: start.getTime() - H + i * H, p: 0.5 + Math.abs(Math.sin(i / 3)) * 1.5 }));
const dom = new JSDOM(html, { runScripts: 'dangerously', pretendToBeVisual: true, url: 'http://localhost/',
  beforeParse(w) {
    Object.defineProperty(w.HTMLElement.prototype, 'clientHeight', { get() { return this.id === 'tl' ? 546 : 0; } });
    w.getComputedStyle = () => ({ fontSize: '10px' });
    w.fetch = async (u) => ({ ok: true, json: async () => ({ '/api/weather': weather, '/api/events': events, '/api/prices': prices }[u]) });
  } });
setTimeout(() => {
  const d = dom.window.document;
  const q = (s) => [...d.querySelectorAll(s)];
  console.log('temp/cond/feel:', d.querySelector('.temp').textContent, d.querySelector('.cond').textContent, '|', d.querySelector('.feel').textContent);
  console.log('alerts:', q('.alert').map((a) => a.className.replace('alert ', '') + ': ' + a.querySelector('.t').textContent + ' / ' + a.querySelector('.s').textContent));
  console.log('all-day:', q('.chip').map((c) => c.textContent));
  console.log('events:', q('.ev').map((e) => e.className.replace('ev ', '') + ' ' + e.querySelector('.t').textContent + ' left=' + e.style.left + ' w=' + e.style.width + ' top=' + e.style.top));
  console.log('rows:', q('.hr').length, 'hours', q('.hr').map((x) => x.textContent).join(' '));
  console.log('bars:', q('.pr .bar').length, 'teal:', q('.pr .bar').filter((b) => b.style.background.includes('94, 209, 177') || b.style.background === '#5ED1B1' || b.style.background === 'rgb(94, 209, 177)').length);
  console.log('midnight divider:', !!d.querySelector('.mid'), 'stale:', JSON.stringify(d.querySelector('.stale').textContent));
  process.exit(0);
}, 300);
