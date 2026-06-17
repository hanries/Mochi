# Mochi API proxy (Cloudflare Worker)

Holds the Anthropic + Edamam API keys server-side so the iOS app ships with no
keys. The app talks only to this Worker.

## Deploy (free, no credit card)

```bash
cd proxy
npm install -g wrangler        # or: brew install cloudflare-wrangler
wrangler login                 # opens browser, sign in / sign up free

# Store the keys as secrets (you'll be prompted to paste each value):
wrangler secret put ANTHROPIC_API_KEY
wrangler secret put EDAMAM_APP_ID
wrangler secret put EDAMAM_APP_KEY

wrangler deploy
```

`wrangler deploy` prints your URL, e.g. `https://mochi-proxy.<you>.workers.dev`.

## Point the app at it

Add this line to `EasyFit/Config.xcconfig` (gitignored), then rebuild:

```
PROXY_BASE_URL = https:/$()/mochi-proxy.<you>.workers.dev
```

(The `/$()/` is an xcconfig quirk so the `//` isn't read as a comment.)

Once the proxy works, **delete `ANTHROPIC_API_KEY`, `EDAMAM_APP_ID`, and
`EDAMAM_APP_KEY` from `Config.xcconfig`** — the app no longer needs them, and
then no key ships in the build at all.

## Endpoints

- `POST /scan` — body is the Anthropic Messages payload; returns Anthropic's response verbatim.
- `GET /foods?ingr=<query>` — returns Edamam's parser response verbatim.

## Note on abuse

This is a thin proxy: anyone who finds the URL could call it on your dime.
Fine for TestFlight. Before a public launch, add a guard — simplest is App
Attest / DeviceCheck (a per-device token the Worker verifies), plus Cloudflare
rate limiting.
