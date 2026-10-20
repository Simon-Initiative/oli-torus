# Transport and response headers

This is the deployment and verification runbook for MER-5179. Application changes
preserve LTI 1.3 cross-site POST launches and embedded delivery. Production TLS and
edge headers must also be updated at the actual HTTPS terminator; deploying Torus
alone does not change a proxy's accepted ciphers or its HSTS override.

## Application behavior

- `_oli_key` remains host-only, `Path=/`, `Secure`, `HttpOnly`, `SameSite=None`.
  The shared cookie carries OIDC launch state and the authenticated session.
  Changing its name, scope or SameSite behavior requires a separate migration.
- Dynamic responses send `Cache-Control: private, no-store`, including redirects,
  API responses, authentication, LTI and handled errors. The endpoint registers
  `Oli.Plugs.NoCache` before parsing/routing and finalizes the header before send.
  Server-side content caches and sessions are unaffected.
- `Plug.Static` serves assets before that plug. Public JWKS and developer-key
  responses preserve their prior policy. The external GIF proxy preserves its
  five-minute **private** caching of non-personalized media bytes. These controller
  exceptions apply only to successful responses that do not set cookies. New
  exceptions require review of the response content, not just its content type.
- HTML lacking CSP receives `base-uri 'self'`. Existing route-specific policies
  are preserved, including same-origin framing restrictions on login pages and
  permissive delivery framing. There is no global enforced script, form, object,
  frame-source or connection restriction.
- The application HSTS policy explicitly uses one year and applies only to the
  responding host. It does not opt installations into subdomain enforcement or
  preload enrollment. HTTPS/HSTS runs before static delivery as well as dynamic
  routes. The existing HTTP health-check bypass remains.
- When configured to terminate HTTPS directly, Torus allows TLS 1.2 ECDHE/AES-GCM
  and TLS 1.3 AEAD suites through `OliWeb.TransportSecurity.https_options/0`.
  Outbound TLS clients are unaffected.

The direct-HTTPS runtime configuration previously read the certificate and key
environment variables in reverse. It now correctly reads `SSL_CERT_PATH` as the
certificate and `SSL_KEY_PATH` as the private key, matching development configuration.
If a deployment worked around the old reversal, correct its variable values before
upgrading. Proxy-terminated deployments do not use these variables.

`no-store` prevents new HTTP cache storage; it does not erase old cache entries or
guarantee that browser history restores no UI state. Check logout/back navigation
in real browsers and invalidate any previously cached sensitive edge objects.

## Optional CSP measurement

Start in staging with this runtime environment variable and restart Torus:

```sh
CSP_REPORT_ONLY="default-src 'self'; base-uri 'self'; object-src 'none'"
```

The value is limited to 4096 bytes and must not contain CR, LF or NUL. It is emitted
as `Content-Security-Policy-Report-Only` only on HTML. It never replaces the enforced
policy. Unset the variable (or set it to an empty value) and restart to disable it.

Initially inspect browser developer tools during the acceptance matrix below.
This example intentionally reveals external-resource, inline-script and PDF embed
dependencies. Violations are expected and do not block them. No network reporting
destination or public collector is enabled by default.

Before adding `report-uri` or `report-to`, verify an approved destination and its
rate limits, body-size limits, retention, access controls and URL sanitization.
Reports can contain learner/document URLs, query parameters and source locations.
Do not collect script samples or forward unsanitized launch URLs/tokens to a third
party. A `report-to` group also requires a matching Reporting-Endpoints setup.
Do not configure a destination merely to satisfy a scanner.

Do not promote the example wholesale to enforcement. In particular:

- `frame-ancestors 'self'` and X-Frame-Options SAMEORIGIN/DENY break LMS embedding.
- `form-action 'self'` can break outbound LTI form posts.
- Restrictive `script-src`/`default-src` block existing inline/external scripts.
- `object-src 'none'` breaks the PDF certificate `<embed>` surfaces.
- `connect-src` must account for LiveView WebSockets and activity services.
- `frame-src` must account for course embeds and external tools.

For a later LMS ancestor allowlist, inventory the actual browser origins of every
ancestor, including custom LMS domains and nested frames. LTI issuer URLs alone
are not an authoritative origin inventory. Multiple enforced CSP headers intersect;
an application policy cannot loosen an edge policy.

## Production TLS change

1. Identify all public TLS terminators, their software versions and certificate
   types. Save the deployed configuration and record its rollback procedure.
2. Review supported browser and server-client TLS capabilities (LMS/API clients,
   integrations and monitoring). Retain TLS 1.2. Do not bundle an infrastructure
   version upgrade into this change without a separate compatibility assessment.
3. Apply the following to a modern HAProxy/OpenSSL deployment. These globals affect
   every TLS bind using their defaults; scope to the Torus listener if the proxy
   serves other applications. Confirm there is no listener-level cipher override.

```haproxy
global
    ssl-default-bind-options ssl-min-ver TLSv1.2
    ssl-default-bind-ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256
    ssl-default-bind-ciphersuites TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256
```

4. Validate using `haproxy -c -f <configuration>` with the deployed binary, then use
   its normal graceful reload. Monitor handshake failures and LMS launch errors.
5. Use the same policy for direct application HTTPS only where that listener is
   actually exposed. Restrict plaintext origins to trusted proxies; overwrite
   X-Forwarded-Proto at the proxy rather than trusting client-supplied values.

The configuration in `guides/starting/self-hosted.md` contains the full example.
It is deployment guidance, not a representation of the currently deployed host.

## Production HSTS change

The investigation observed:

```http
Strict-Transport-Security: max-age=16000000; includeSubDomains; preload;
```

Confirm this is still the effective value and identify the layer setting it.
Inspect every descendant of the Torus hostname, including internal hosts. Verify
HTTPS/certificate renewal and that preload intent is deliberate. Do not expand
the policy to a parent domain as part of this change.

For an audited production host intentionally retaining its existing subdomain and
preload intent, change the edge value to:

```haproxy
http-after-response set-header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
```

Use this in the HTTPS frontend so static files, application responses, redirects,
and proxy-generated errors receive a single effective policy. Confirm support for
`http-after-response` in the deployed version. If unsupported, prepare a compatible
equivalent covering generated errors before rollout; do not blindly reload it.
The portable self-hosting example defaults to `max-age=31536000` without opt-ins.

Do not submit any domain to a preload list as part of this change. Sending the
directive does not prove enrollment, and one-year HSTS without enrollment still
provides meaningful protection. Changing preload intent requires a separate
operator decision. HSTS is persisted in browsers, so server rollback is not an
instant reversal of clients' remembered policies.

## Verification and release gates

Run the header, cookie, TLS, authentication and LTI regression tests. Local TLS
tests exercise actual handshakes, but do not certify every deployed certificate
type, proxy build or external client.

Before production closure, test the supported LMS/browser matrix in staging:

| Flow | Required result |
| --- | --- |
| Student/instructor launch, fresh/existing session | Successful OIDC round trip in iframe and new window |
| Deep link and external-tool return | Cross-origin form posts complete |
| Course navigation and LiveView reconnect | Session persists in the LMS frame |
| Assessment submit, back navigation and resume | Work is saved and resumes correctly |
| Logout and subsequent history navigation | Sensitive responses are not newly stored or served by shared caches |
| Certificates, media and representative activities | PDF embeds, scripts, frames and connections still work |
| Missing/mismatched state, invalid JWT, replay | Existing validation rejects invalid launches |
| Ordinary browser mutation without CSRF token | Request rejected; LTI protocol entry points remain exempt |
| Existing third-party-cookie-blocking configurations | No regression in supported behavior or launch error handling |

After independent application/TLS/HSTS rollouts, verify the actual external host:

```sh
curl -sS -D - -o /dev/null https://<torus-host>/users/log_in
curl -sS -D - -o /dev/null https://<torus-host>/lti/register_form
curl -sS -I http://<torus-host>/
```

Also inspect authenticated delivery/API/download responses in a controlled browser
session, LTI redirects and failures, proxy errors, and versioned assets. Never put
session cookies or tokens in shared logs. Confirm `private, no-store` on sensitive
responses, the expected route-specific CSP, unchanged cookie attributes, static
caching, and the final HSTS value with no duplicate/conflicting edge policy.

Run a complete protocol/cipher scan over all public listeners. With a suitable
OpenSSL client, these representative negotiations supplement that scan:

```sh
openssl s_client -connect <torus-host>:443 -servername <torus-host> -tls1_2 -cipher ECDHE-RSA-AES256-GCM-SHA384
openssl s_client -connect <torus-host>:443 -servername <torus-host> -tls1_3
openssl s_client -connect <torus-host>:443 -servername <torus-host> -tls1_2 -cipher ECDHE-RSA-AES256-SHA
```

The first two must succeed for an RSA deployment with TLS 1.3; the CBC attempt must
fail. Also test TLS 1.0/1.1 rejection and ECDSA suites where deployed. Distinguish a
client build lacking a protocol/cipher from a server rejection.

## Rollback and remaining scope

Deploy application headers, edge TLS and HSTS independently. Roll back the relevant
application release or saved proxy configuration if launch, rendering, handshake or
load metrics regress. Disable report-only independently by clearing its variable.
Do not relax launch validation to compensate for a header/cookie regression.

The application tests do not certify production deployment or a real LMS/browser
matrix. Ticket closure requires that evidence and the authenticated rescan.
The baseline CSP is partial defense, not comprehensive XSS/clickjacking mitigation.
Full CSP enforcement and LMS framing allowlists remain staged follow-up work.
SameSite=None remains a justified LTI exception. The API pipeline accepts sessions
without the browser CSRF plug; a broader route-specific CSRF audit is still needed,
and is not remediated by this header change.

References: [HSTS preload guidance](https://hstspreload.org/),
[1EdTech browser cookies and LTI](https://www.imsglobal.org/browser-cookies-and-lti),
[CSP](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CSP), and
[OWASP TLS guidance](https://cheatsheetseries.owasp.org/cheatsheets/Transport_Layer_Security_Cheat_Sheet.html).
