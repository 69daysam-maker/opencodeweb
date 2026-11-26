import { AgentContainer } from "./container"

export { AgentContainer }

/**
 * One deployment serves both halves on one origin:
 *
 *   GET /_assets/app.js        -> the built SolidJS UI
 *   GET /api/...               -> the opencode server inside the container
 *   GET /... (WebSocket)       -> the same server, upgraded
 *
 * Same origin is what makes this work without CORS and without mixed content:
 * a production build resolves its server URL to `location.origin`.
 */
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const upgrade = request.headers.get("Upgrade")?.toLowerCase()

    // Static files first, so the UI loads without waking a container.
    if ((request.method === "GET" || request.method === "HEAD") && upgrade !== "websocket") {
      const asset = await env.ASSETS.fetch(request)
      if (asset.status !== 404) return asset

      // A client-side route such as /session/abc has no file behind it.
      const accept = request.headers.get("Accept") ?? ""
      if (accept.includes("text/html") && !new URL(request.url).pathname.includes(".")) {
        return env.ASSETS.fetch(new Request(new URL("/index.html", request.url), request))
      }
    }

    // Personal deployment: every request goes to the same agent.
    // For one container per user, derive this name from the authenticated
    // user's id instead of the constant.
    const agent = env.AGENT.get(env.AGENT.idFromName("default"))
    return agent.fetch(request)
  },
}
