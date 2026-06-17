// Mochi API proxy (Cloudflare Worker)
//
// Keeps the Anthropic and Edamam API keys server-side so the iOS app ships
// with NO keys. The app calls:
//   POST /scan          → forwarded to Anthropic Messages API (key injected)
//   GET  /foods?ingr=…  → forwarded to Edamam food parser (keys injected)
//
// Keys are Worker *secrets* (never in this file or git):
//   wrangler secret put ANTHROPIC_API_KEY
//   wrangler secret put EDAMAM_APP_ID
//   wrangler secret put EDAMAM_APP_KEY

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const json = (obj, status = 200) =>
      new Response(JSON.stringify(obj), { status, headers: { "content-type": "application/json" } });

    try {
      // --- Food photo scan → Anthropic ---
      if (url.pathname === "/scan" && request.method === "POST") {
        const body = await request.text(); // {model, max_tokens, messages:[…]}
        const r = await fetch("https://api.anthropic.com/v1/messages", {
          method: "POST",
          headers: {
            "content-type": "application/json",
            "x-api-key": env.ANTHROPIC_API_KEY,
            "anthropic-version": "2023-06-01",
          },
          body,
        });
        return new Response(await r.text(), {
          status: r.status,
          headers: { "content-type": "application/json" },
        });
      }

      // --- Food search → Edamam ---
      if (url.pathname === "/foods" && request.method === "GET") {
        const ingr = url.searchParams.get("ingr") || "";
        if (!ingr) return json({ error: "missing ingr" }, 400);
        const e = new URL("https://api.edamam.com/api/food-database/v2/parser");
        e.searchParams.set("app_id", env.EDAMAM_APP_ID);
        e.searchParams.set("app_key", env.EDAMAM_APP_KEY);
        e.searchParams.set("ingr", ingr);
        e.searchParams.set("nutrition-type", "logging");
        const r = await fetch(e.toString(), { headers: { accept: "application/json" } });
        return new Response(await r.text(), {
          status: r.status,
          headers: { "content-type": "application/json" },
        });
      }

      return json({ error: "not found" }, 404);
    } catch (err) {
      return json({ error: String(err) }, 502);
    }
  },
};
