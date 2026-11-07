# Kitchen family dashboard

Portrait display for the family kitchen: weather, today's calendar with attendee avatars, and electricity prices on one shared hour axis. Runs on a tablet now; an e-ink display (maybe TRMNL) is a later step.

## Layout (decided)

- Dark, 480x800 portrait, scales to the viewport (everything in rem, `html { font-size: min(100vw/48, 100vh/80) }`).
- No date or clock (the kitchen already has plenty).
- Top: current temperature + condition. Alert cards appear only when relevant: rain (rain in the next 4 h), sunscreen (UV >= 3), good sailing. Nothing shown when nothing is worth flagging.
- All-day events: chips above the timeline.
- Timeline: hour axis on the left, events in the middle (overlapping events split into columns, the event happening now is inverted), hourly price bars on the right. Bars are right-aligned from a solid axis, price printed left of each bar. Cheapest 4 consecutive hours = teal, expensive hours = orange, rest = slate. Dashed line marks midnight ("TOMORROW"). Number of hour rows adapts to the free height.
- Avatars are one size everywhere; each person has an initial + colour.
- Visual reference: `design/Timeline480-display.dc.html` (a Design Component page from claude.ai, not runnable here). Canvas with all explored directions: https://claude.ai/artifact/AzyGXCBkXWCwtzTjggWRYv

## Files

Hanami 3 app (Ruby 4, no DB, no assets). The page is rendered on the server; the browser only re-fetches it every minute (swapping `#app` in place, keeping the old page on failure) and requests a screen wake lock.

- `config/dashboard.rb`: household config (see below). `config/settings.rb`: `GOOGLE_KEY_FILE`.
- `app/sources/`: data sources, each cached in `app/cache.rb` (in-memory, serves stale data on upstream failure). HTTP via `app/http.rb` (Net::HTTP).
  - `events.rb`: Google Calendar via a service account (JWT signed with OpenSSL), `singleEvents=true`, merges the same event across calendars, handles declined/cancelled, maps calendars and attendee emails to people. Cached 5 min.
  - `weather.rb`: Open-Meteo passthrough using DMI's HARMONIE model (`models=dmi_seamless`); DMI has no UV index, so `uv_index` comes from a second request with Open-Meteo's default model. (DMI's own EDR API at opendataapi.dmi.dk needs no key but only has raw model fields: no weather code, apparent temperature or UV.) Cached 10 min.
  - `prices.rb`: what a kWh actually costs per hour: Energi Data Service `DayAheadPrices` (15-minute resolution since 2025-10-01; `Elspotprices` is discontinued) averaged to hours, + `MARKUP` + tariffs, × VAT. `t` is unix seconds. Cached 30 min.
  - `tariffs.rb`: per-kWh tariffs from EDS `DatahubPricelist` (grid company time-of-day tariff, Energinet transmission + system tariff, elafgift), selected by `TARIFFS`. Cached 24 h.
- `app/display/`: plain Ruby presentation logic. `weather.rb` (condition text, rain/sunscreen/sailing alerts and their thresholds), `timeline.rb` (hour rows, event columns, cheapest/expensive price bars and their constants), `layout.rb` (timeline height from the fixed 48x80 rem canvas: the number of hour rows is computed server-side, so the heights there must match the CSS).
- `app/views/dashboard/show.rb` + `app/templates/dashboard/show.html.erb`: the page. CSS and the small client script are in `app/templates/layouts/app.html.erb`.
- `app/actions/api/`: `/api/events`, `/api/weather`, `/api/prices` serve the sources as JSON (502 if the upstream fails and nothing is cached). Useful for debugging.
- `spec/`: `bundle exec rspec`. Sources are tested with a fake HTTP client; display logic with fixtures; request specs stub the sources in the container.
- `legacy-node/`: the previous Node implementation, kept for reference.

## Config (`config/dashboard.rb`)

`LAT`/`LON` (our town), `PRICE_AREA` (DK1: our town), `MARKUP` (supplier markup, lambda taking the hour's `Time`), `VAT`, `TARIFFS` ([GLN, charge code] pairs), `PEOPLE`, `CALENDARS`.

Electricity: the supplier moove, grid company the grid company El-Net (tariff C). Price per kWh = (spot + the supplier markup 6.4 øre ex VAT, 0 in the first 6 months + the grid company Nettarif C + Energinet transmission + system tariff + elafgift) × 1.25. Verified against invoice the latest invoice (Oct 2026): the "Transport og afgifter" line also contains two fixed monthly subscriptions (the grid company Net abo C 44 kr, Energinet TSO system abonnement 15.58 kr, ex VAT) that don't affect the per-kWh price. No separate trading-cost line on the invoice. Needs `service-account.json` (or `GOOGLE_KEY_FILE`), with each calendar shared with the service account email ("See all event details"). `TZ` defaults to Europe/Copenhagen.

Run: `bundle exec puma -C config/puma.rb` (`PORT`/`HOST` env, default 0.0.0.0:8080). Dev with code reloading: `bin/dev`.

## Status

- Open-Meteo and Energi Data Service verified live (2026-11-07). EDS `start`/`end` are read as Danish local time (first hour returned is local midnight) and `TimeUTC` has no trailing Z.
- Google Calendar is tested only against mocks; not yet run with real credentials.
- On macOS with mise's Ruby, `/etc/ssl/cert.pem` lacks GlobalSign Root R46, so TLS to EDS fails locally. Workaround: `security find-certificate -a -p /System/Library/Keychains/SystemRootCertificates.keychain > roots.pem` and run with `SSL_CERT_FILE=roots.pem`. A Linux server with current `ca-certificates` should not need this.

Assumptions still to verify against live data:
- Open-Meteo hourly `precipitation` is the sum over the preceding hour (rain during the hour starting at `time[i]` is `precipitation[i+1]`).
- When the the supplier markup starts (`MARKUP` assumes 2027-01-01; 0 on the Sep 2026 invoice, 6.4 øre in the Jan 2027 aconto).
- Whether the supplier's billed "spotpris" includes trading costs (needs hourly consumption from Eloverblik to check).

## Next steps

1. Run with real Google credentials (`curl localhost:8080/api/events`), fix whatever breaks, and tune thresholds (rain, UV, sailing wind/gust limits).
2. Set real people and calendars.
3. Run it as a service on the home server (systemd running puma) and point the tablet's browser at it in fullscreen/kiosk mode.
4. Later: e-ink/TRMNL version. Needs a 1-bit variant (no grays; solid/outlined/hatched bars; people told apart by shape). Rendering is already server-side, so this is mostly another template/route (TRMNL fetches an image or markup). A 1-bit design exists on the canvas (`Timeline480.dc.html`, `Eink.dc.html`).

## Preferences

Keep things minimal and direct; no defensive over-engineering. Be technically precise.
