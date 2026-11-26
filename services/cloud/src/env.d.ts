// Binding names used by this Worker. `wrangler types` would generate these;
// they are written by hand so the service typechecks before the first deploy.
interface Env {
  AGENT: DurableObjectNamespace
  ASSETS: Fetcher
  /** Set with `wrangler secret put OPENROUTER_API_KEY`; never in this file. */
  OPENROUTER_API_KEY?: string
}
