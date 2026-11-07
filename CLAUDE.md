# Kitchen family dashboard

Portrait display for the family kitchen: weather, today's calendar with attendee avatars, and electricity prices on one shared hour axis. Runs on a tablet now; an e-ink display (maybe TRMNL) is a later step.

## Layout (decided)

- Dark, designed for 480x800 portrait, scales to the viewport (everything in rem, `html { font-size: min(100vw/48, 100vh/80) }`). 80 rem tall; the width is fluid (at least 48 rem), so on screens wider than 3:5 the calendar column takes the extra width instead of leaving side margins.
- UI text in Danish (decimal comma, Danish compass points).
- No date or clock (the kitchen already has plenty).
- Top: big current temperature, condition + "feels like" to its right. Below it, a horizontal row of alert tiles, only when relevant: rain (rain in the next 4 h), sunscreen (UV >= 3), good sailing (wind written "5 (8) m/s" = wind (gusts), as DMI does). No row when nothing is worth flagging; with all three, the tiles drop their icons to fit at 480 px.
- Today's all-day events: chips above the events list (later ones are rows in the list).
- Tentative events (the family's convention: title starts with "?"): dashed outline, no fill, dimmed text and avatars, both in the events list and as all-day chips. The "?" stays in the title.
- Events: a compact list (like canvas direction A's "TODAY") of the next events, however far off (fetched 14 days ahead, `DAYS_AHEAD` in `app/sources/events.rb`). One fixed-height row per event: start time + "til HH:MM" (future all-day events: "hele dagen"), title + location, avatars. A divider per later day ("I MORGEN", "MANDAG 9. NOV"). Finished events are dropped; the current one is inverted. As many rows as fit (computed server-side); the rest become "+ N flere". "Ingen aftaler" when there are none.
- Electricity prices: a bar chart along the bottom (like canvas directions A/C): 24 bars from the current hour (empty slots where tomorrow isn't published yet), 0–3 kr/kWh scale with dearer hours cut off (flat top), reference lines at 2 kr (grey) and 1 kr (green), bars below 1 kr teal, current hour lighter, current price in large type, hour labels "Nu" and 00/06/12/18. Line labels sit in a left gutter.
- Avatars are one size everywhere; each person has an initial + colour.
- Visual reference: `design/Timeline480-display.dc.html` (a Design Component page from claude.ai, not runnable here). Canvas with all explored directions: https://claude.ai/artifact/AzyGXCBkXWCwtzTjggWRYv

## Files

Hanami 3 app (Ruby 4, no DB, no assets). The page is rendered on the server; the browser only re-fetches it every minute (swapping `#app` in place, keeping the old page on failure) and requests a screen wake lock. When the server has restarted (`App::BOOT_ID` in the `boot-id` meta tag changed) it reloads fully instead, so CSS/script changes reach installed copies without a manual reload.

- `config/dashboard.rb`: household config (see below). `config/settings.rb`: `GOOGLE_TOKEN_FILE`.
- `app/sources/`: data sources, each cached in `app/cache.rb` (in-memory, serves stale data on upstream failure). HTTP via `app/http.rb` (Net::HTTP).
  - `events.rb`: Google Calendar (today + 14 days) as Parent A's Google account (OAuth refresh token from `bin/google-auth`), `singleEvents=true`, merges the same event across calendars, handles declined/cancelled, maps calendars and attendee emails to people. Cached 5 min.
  - `weather.rb`: Open-Meteo passthrough using DMI's HARMONIE model (`models=dmi_seamless`); DMI has no UV index, so `uv_index` comes from a second request with Open-Meteo's default model. (DMI's own EDR API at opendataapi.dmi.dk needs no key but only has raw model fields: no weather code, apparent temperature or UV.) Cached 10 min.
  - `prices.rb`: what a kWh actually costs per hour: Energi Data Service `DayAheadPrices` (15-minute resolution since 2025-10-01; `Elspotprices` is discontinued) averaged to hours, + `MARKUP` + tariffs, × VAT. `t` is unix seconds. Cached 30 min.
  - `tariffs.rb`: per-kWh tariffs from EDS `DatahubPricelist` (grid company time-of-day tariff, Energinet transmission + system tariff, elafgift), selected by `TARIFFS`. Cached 24 h.
- `app/display/`: plain Ruby presentation logic. `weather.rb` (condition text, rain/sunscreen/sailing alerts and their thresholds), `agenda.rb` (the events list and its row sizes), `prices.rb` (the price chart and its scale/line/cheap constants), `layout.rb` (height left for the events list on the 80 rem tall canvas: how many rows fit is computed server-side, so the heights there and in `agenda.rb` must match the CSS).
- `app/views/dashboard/show.rb` + `app/templates/dashboard/show.html.erb`: the page. CSS is in `app/templates/layouts/app.html.erb`, the client script in `public/app.js` (Hanami's default Content-Security-Policy blocks inline scripts; `config/app.rb` also allows the manifest and Google Fonts).
- Installable web app (no service worker): `public/manifest.webmanifest` (`display: fullscreen`, portrait) and `public/icons/` (`icon.svg` is the source; PNGs rendered from it with headless Chrome + `sips`), served by `Rack::Static` (config/app.rb). iOS meta tags in the layout; the canvas is shrunk by `env(safe-area-inset-*)` so it clears the translucent iOS status bar. Android only offers install/fullscreen, and browsers only allow the screen wake lock, on a secure origin (HTTPS or localhost); plain `http://<lan-ip>` won't do it (workaround on the tablet: `chrome://flags` → "Insecure origins treated as secure"). iOS "Add to Home Screen" works over HTTP.
- `app/actions/api/`: `/api/events`, `/api/weather`, `/api/prices` serve the sources as JSON (502 if the upstream fails and nothing is cached). Useful for debugging.
- `spec/`: `bundle exec rspec`. Sources are tested with a fake HTTP client; display logic with fixtures; request specs stub the sources in the container.
- `legacy-node/`: the previous Node implementation, kept for reference.

## Config (`config/dashboard.rb`)

`LAT`/`LON` (our town), `PRICE_AREA` (DK1: our town), `MARKUP` (supplier markup, lambda taking the hour's `Time`), `VAT`, `TARIFFS` ([GLN, charge code] pairs), `PEOPLE` (J = Parent A, T = Parent B, Ma = Child A, Mt = Child B), `CALENDARS` (Google: Parent A's personal, Parent B's, Child A, Child B, Familie = all, Fælles = J+T; Parent A's work and Projects calendars are left out on purpose; `who` is a list of PEOPLE keys).

Electricity: the supplier moove, grid company the grid company El-Net (tariff C). Price per kWh = (spot + the supplier markup 6.4 øre ex VAT, 0 in the first 6 months + the grid company Nettarif C + Energinet transmission + system tariff + elafgift) × 1.25. Verified against invoice the latest invoice (Oct 2026): the "Transport og afgifter" line also contains two fixed monthly subscriptions (the grid company Net abo C 44 kr, Energinet TSO system abonnement 15.58 kr, ex VAT) that don't affect the per-kWh price. No separate trading-cost line on the invoice.

Google: needs `google-token.json` (or `GOOGLE_TOKEN_FILE`), made once with `bin/google-auth client_secret.json`. Setup: Google Cloud project → enable the Google Calendar API → OAuth consent screen (External, scope `calendar.readonly`), **publish it to "In production"** (in "Testing", refresh tokens expire after 7 days; for personal use, click past the "unverified app" warning) → Credentials → OAuth client ID of type "Desktop app" → download the JSON. Run the script on a machine with a browser (it listens on a 127.0.0.1 port for the redirect) and copy `google-token.json` to the server. The token stops working if unused for 6 months or if access is revoked in the Google account. Gitignored: `google-token.json`, `client_secret*.json`.

`TZ` defaults to Europe/Copenhagen.

Run: `bundle exec puma -C config/puma.rb` (`PORT`/`HOST` env, default 0.0.0.0:8080). Dev with code reloading: `bin/dev`.

## Status

- Open-Meteo and Energi Data Service verified live (2026-11-07). EDS `start`/`end` are read as Danish local time (first hour returned is local midnight) and `TimeUTC` has no trailing Z.
- Google Calendar verified live (2026-11-07) via OAuth (consent screen published "In production", unverified; branding filled in only because publishing requires it).
- On macOS, mise's Ruby has OpenSSL compiled in and reads macOS's `/etc/ssl/cert.pem`, which lacks GlobalSign Root R46, so TLS to EDS fails locally (upgrading MacPorts `curl-ca-bundle` alone doesn't help). Fix: `SSL_CERT_FILE=/opt/local/share/curl/curl-ca-bundle.crt` (MacPorts' bundle has R46), in `~/.zshrc` or `.env.local`. A Linux server with current `ca-certificates` should not need this.

Assumptions still to verify against live data:
- Open-Meteo hourly `precipitation` is the sum over the preceding hour (rain during the hour starting at `time[i]` is `precipitation[i+1]`).
- When the the supplier markup starts (`MARKUP` assumes 2027-01-01; 0 on the Sep 2026 invoice, 6.4 øre in the Jan 2027 aconto).
- Whether the supplier's billed "spotpris" includes trading costs (needs hourly consumption from Eloverblik to check).

## Next steps

1. Tune thresholds (rain, UV, sailing wind/gust limits) against real conditions.
2. Copy `google-token.json` to the home server along with the app.
3. Run it as a service on the home server (systemd running puma), ideally behind HTTPS (e.g. Caddy or Tailscale serve) so Android install and the wake lock work, and install it on the tablet from the browser.
4. Later: e-ink/TRMNL version. Needs a 1-bit variant (no grays; solid/outlined/hatched bars; people told apart by shape). Rendering is already server-side, so this is mostly another template/route (TRMNL fetches an image or markup). A 1-bit design exists on the canvas (`Timeline480.dc.html`, `Eink.dc.html`).

## Preferences

Keep things minimal and direct; no defensive over-engineering. Be technically precise.
