# Security Review Checklist

> Use this file during PR review to catch vulns and regressions early. Leave **specific, actionable** comments (file:line, suggested fix). Aim for least privilege, defense-in-depth, and secure defaults.

---

## 1) Industry-Agnostic Best Practices (OWASP-aligned)

### Authentication & Session
- [ ] All routes requiring auth are actually **gated**; no “UI-only” gating.
- [ ] **Session cookies**: `Secure`, `HttpOnly`, `SameSite=Lax/Strict` set; short, rotation-friendly lifetime.
- [ ] **Password flows**: modern KDF (Argon2/Bcrypt/PBKDF2) with per-user salt; constant-time comparisons.
- [ ] **MFA / recovery tokens**: single-use, short TTL, server-side invalidation on use.
- [ ] **Account enumeration** avoided (generic messages, uniform timing).

### Authorization
- [ ] **Server-side authorization for every state-changing action** (no trust of client/DOM).
- [ ] **Policy/permission checks centralized** (e.g., policy modules) and enforce object-level checks (resource ownership/tenant).
- [ ] **Deny-by-default**: missing policy => forbidden.

### Input Validation & Output Encoding
- [ ] **Strict validation** at boundaries (controllers, LiveView events, APIs).
- [ ] **Output encoding** appropriate to sink (HTML, JS, JSON, SQL, shell).
- [ ] Never interpolate untrusted data into templates, SQL, shell, or eval-like APIs.

### Data Protection & Privacy
- [ ] **Encrypt sensitive fields at rest** (PII, secrets) and in transit (TLS).
- [ ] **Minimize collection**; store only necessary data, with clear retention & deletion paths.
- [ ] **Logs/events** exclude secrets, tokens, and sensitive user data (mask/redact).

### Secrets Management
- [ ] No secrets in code, configs, or Git history; load at runtime from env/secret store.
- [ ] **Key rotation** supported; failures are explicit (e.g., `System.fetch_env!`).

### Dependency & Supply Chain
- [ ] Dependencies pinned; **security audit** in CI; review transitive risk.
- [ ] No unvetted third-party scripts; lock CDN/external assets with SRI (or avoid entirely).

### Web App Protections
- [ ] **CSRF** protected on state-changing routes.
- [ ] **CORS** restricted to known origins; no wildcard credentials.
- [ ] **Headers**: CSP, HSTS, X-Content-Type-Options, X-Frame-Options/Frame-Ancestors, Referrer-Policy.

### DoS / Resource Abuse
- [ ] **Rate limits** / circuit breakers on login, signup, search, file upload, webhooks.
- [ ] Bounded concurrency & timeouts for external I/O.

### File Handling
- [ ] Enforce **content-type/size allowlists**; randomize names; store outside webroot; virus-scan if applicable.

### Observability
- [ ] Metrics/alerts for auth failures, permission denials, rate-limit hits, 4xx/5xx spikes.
- [ ] Security-relevant events are structured & traceable (who, what, when, where).

---

## 2) Elixir / Phoenix / Ecto (Reviewer Checklist)

### Router / Plugs / Endpoint
- [ ] **CSRF**: `protect_from_forgery` is active in the `:browser` pipeline and forms include the token.
- [ ] **Secure headers** via `put_secure_browser_headers` (add CSP/HSTS as needed).
- [ ] **TLS** enforced (`force_ssl` / `Plug.SSL`) with proxy correctness (`:rewrite_on` if behind LB).
- [ ] **CORS** plug (if used) locked to known origins; no wildcard with credentials.

### LiveView / Templates
- [ ] **No inline `<script>`** tags in HEEx; scripts live in `assets/js`.
- [ ] Avoid `Phoenix.HTML.raw/1` and manual `safe_to_string` with untrusted input.
- [ ] **Use `~H` HEEx**; rely on default escaping. Interpolate in attrs with `{...}`, not `<%= ... %>`.
- [ ] **Forms**: use `to_form/2` + `<.form>`/`<.input>`; do not access raw changesets in templates.

### Ecto / Data Layer
- [ ] **Parameterized queries** only; never string-interpolate SQL. Treat `fragment/1` with extreme caution.
- [ ] **Mass-assignment protection**: `cast/3` only whitelists safe fields; **server-set fields** (e.g., `user_id`, `role`, `org_id`, `is_admin`, `published_at`) are **not** castable—set explicitly in code.
- [ ] **Constraints** (`unique_constraint`, `foreign_key_constraint`, `check_constraint`) declared so DB rejects invalid/duplicate input.
- [ ] **Preload intentionally**; don’t expose unrelated associations by accident.

### BEAM Safety / General Elixir
- [ ] **Never** call `String.to_atom/1` on user input (atom table DoS). Use `String.to_existing_atom/1` only with strict whitelists, or map strings explicitly.
- [ ] **No dynamic module/function dispatch** from untrusted input without strict whitelists.
- [ ] **Background long I/O/CPU** work (don’t block GenServers); preserve timeouts and cancellations.
- [ ] **Req**: reuse client, set timeouts/retries/backoff; validate TLS; bound concurrency.

### Crypto / Secrets
- [ ] Use a vetted crypto lib; **no home-rolled crypto**. Strong RNG via `:crypto.strong_rand_bytes/1`.
- [ ] Secret config in `config/runtime.exs`; retrieved with `System.fetch_env!`.

### Dependency & Static Analysis
- [ ] **Sobelow** run clean or with reviewed findings.
- [ ] **Credo** style warnings reviewed (readability often prevents security bugs).

### File Uploads (Phoenix LiveView/Controllers)
- [ ] `LiveFileUpload` has **`accept` & size caps**, unique names, validated content type.
- [ ] Storage layer isolates user files; sanitize download filenames/headers.

---

## 3) Torus-Specific Standards (apply verbatim where relevant)

### AuthN/AuthZ flow (Torus routing model)
- [ ] **Authentication handled at the router level** with proper redirects.
- [ ] Routes that **require login live inside the existing** `live_session :require_authenticated_user`
  with `on_mount: [{AppWeb.UserAuth, :ensure_authenticated}]`.
- [ ] Routes that work with or without auth live inside the existing `live_session :current_user`
  with `on_mount: [{AppWeb.UserAuth, :mount_current_scope}]`.
- [ ] **Never duplicate `live_session` names**; group routes correctly to ensure mounts run.

### Templating & Assets
- [ ] **No inline `<script>`**; only `app.js`/`app.css` bundles are supported. Import vendor deps into those bundles (reduces XSS/supply-chain risk).
- [ ] Use the provided `<.input>` and other components from `core_components.ex` instead of ad-hoc HTML inputs.

### Data Handling
- [ ] For fields set programmatically (e.g., ownership, role, section/course IDs), **exclude from `cast`** and set explicitly in code.
- [ ] **Avoid exposing raw attempt data** to unauthorized roles; prefer summarized/aggregated views when appropriate.

---

## Reviewer Red Flags (paste as comments)

- “Do not call `String.to_atom(params["type"])`; map to a known atom or use a string enum instead.”
- “Move this auth-required route under `live_session :require_authenticated_user` and add `on_mount` hook.”
- “Mass-assignment risk: field `:role` should not be in `cast/3`; set it server-side.”
- “Replace string-built SQL with parameterized Ecto query (see snippet).”
- “Remove inline `<script>` in HEEx; move script to `assets/js` and import in `app.js`.”
- “Add CSRF protection to this POST/PUT/DELETE path (browser pipeline or explicit token).”
- “Add CSP/HSTS headers in endpoint config; document policy.”
- “Add `accept` and size caps to LiveFileUpload; validate content-type and randomize filenames.”
- “Rate-limit this login/webhook endpoint (possible brute force/DoS).”
- “Secrets must be read from env at runtime; remove from config/code.”

---

## Quick Verification Steps

- [ ] **Headers check** in browser/`curl -I`: CSP/HSTS/X-Frame/XCTO/Referrer present and correct.
- [ ] **CSRF** token present on forms; state-changing routes live in CSRF-protected pipeline.
- [ ] **AuthZ tests**: add/confirm negative tests (unauthorized user cannot access/modify resource).
- [ ] **CORS**: verify allowed origins list and method set.
- [ ] **Secrets**: grep PR for keys/tokens; ensure `runtime.exs`/ENV usage.
- [ ] **Tenancy**: confirm queries are scoped to `current_scope` (no unscoped cross-tenant reads/writes).

---

## Snippets (drop into review as needed)

**Ecto mass-assignment guard**
```elixir
# Bad: user controls role/org_id via params
def changeset(user, params),
  do: user |> cast(params, [:email, :role, :org_id])

# Good: server sets sensitive fields
def changeset(user, params) do
  user
  |> cast(params, [:email])
  |> put_change(:org_id, org_id)   # from current_scope
  |> put_change(:role, "member")   # server choice
end
