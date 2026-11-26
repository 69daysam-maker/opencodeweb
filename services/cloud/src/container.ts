import { DurableObject } from "cloudflare:workers"

const AGENT_PORT = 4096

/**
 * One Durable Object owns one container instance. Every request for that
 * instance passes through here, which is also where lifecycle lives:
 * Cloudflare stops the container after the inactivity timeout with no traffic,
 * and the next request starts it again.
 */
export class AgentContainer extends DurableObject<Env> {
  /** Shared across concurrent requests so a cold start is only paid once. */
  private starting: Promise<void> | undefined

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env)
    // Without an inactivity timeout the VM keeps billing while nobody is
    // using it. Ten minutes of silence stops it; the next request wakes it.
    void ctx.blockConcurrencyWhile(async () => {
      await ctx.container?.setInactivityTimeout(10 * 60 * 1000)
    })
  }

  private async ready() {
    const container = this.ctx.container
    if (!container) throw new Error("No container is bound to this Durable Object")

    this.starting ??= (async () => {
      container.start({
        enableInternet: true,
        env: {
          // The key never reaches the browser; it only exists inside the VM.
          OPENROUTER_API_KEY: this.env.OPENROUTER_API_KEY ?? "",
          OPENCODE_SERVER_PORT: String(AGENT_PORT),
          HOME: "/root",
        },
      })

      // start() returns before the process listens. Wait for it, so the first
      // request after a cold start is slow instead of broken.
      await container.monitor()
    })().finally(() => {
      this.starting = undefined
    })

    await this.starting
  }

  override async fetch(request: Request): Promise<Response> {
    await this.ready()

    const url = new URL(request.url)
    const forwarded = new Request(url, request)
    // The container does not need the Worker's hostname, and keeping it can
    // make the server build the wrong absolute URLs.
    forwarded.headers.delete("host")

    return this.ctx.container!.getTcpPort(AGENT_PORT).fetch(forwarded)
  }
}
