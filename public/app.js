// Re-fetch the page every minute and swap #app in place; on failure keep showing the last page.
// After a server restart (new boot-id) reload fully, so CSS/script changes arrive too.
// Also refresh right away when the page becomes visible (timers are paused while the screen is off).
let okAt = Date.now();
async function refresh() {
  try {
    const r = await fetch(location.href, { cache: 'no-store' });
    if (!r.ok) throw new Error(r.status);
    const doc = new DOMParser().parseFromString(await r.text(), 'text/html');
    const bootId = (d) => d.querySelector('meta[name="boot-id"]').content;
    if (bootId(doc) !== bootId(document)) return location.reload();
    document.getElementById('app').replaceWith(doc.getElementById('app'));
    okAt = Date.now();
  } catch (e) {
    if (Date.now() - okAt > 3 * 60e3) document.querySelector('.stale').textContent = 'offline';
  }
}
setInterval(refresh, 60e3);

const wake = () => navigator.wakeLock && navigator.wakeLock.request('screen').catch(() => {});
document.addEventListener('visibilitychange', () => {
  if (document.visibilityState === 'visible') { wake(); refresh(); }
});
wake();
