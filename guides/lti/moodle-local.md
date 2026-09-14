# Local Moodle and Torus over HTTPS

Use `https://moodle.test:8443` for Moodle and `https://torus.test` for Torus.
Both names must resolve to localhost on the host machine. Moodle's containers
must resolve `torus.test` to Docker's host gateway and trust the shared local CA.
The Moodle repository's `docker/README.md` describes that setup and certificate renewal.

Copy `torus.crt`, `torus.key`, and `root-ca.crt` from Moodle's generated certificates
into `priv/ssl/moodle-local/`. That directory is ignored by Git. Trust the public
CA in your browser/operating system as described in the Moodle setup guide.

After loading your normal Torus development environment, run from the Torus root:

```sh
export SCHEME=https
export HOST=torus.test
export PORT=443
export HTTPS_PORT=443
export SSL_CERT_PATH="$PWD/priv/ssl/moodle-local/torus.crt"
export SSL_KEY_PATH="$PWD/priv/ssl/moodle-local/torus.key"
export LTI_CA_CERT_PATH="$PWD/priv/ssl/moodle-local/root-ca.crt"
mix phx.server
```

Use your normal mechanism for serving port 443. `HTTP_PORT` still controls the
separate HTTP listener; use an available port if the default port 80 is occupied.
`PORT` is the public URL port, while `HTTPS_PORT` is the listener port. Keep the
public port at 443 for the existing Moodle container's allowed-port configuration.

`SSL_CERT_PATH` and `SSL_KEY_PATH` configure incoming TLS. `LTI_CA_CERT_PATH`
selects a development-only LTI HTTP client that adds the local CA to Hackney's
public CA bundle. Peer and hostname verification stay enabled. This covers
Moodle signing-key downloads, OAuth tokens, roster requests, and grade services.
It does not change other HTTP clients or production/test configuration. Restart
Torus after changing environment variables. Unset `LTI_CA_CERT_PATH` to use the
default LTI client again.

## Register the tool

In Moodle, create an LTI 1.3 external tool with these Torus endpoints:

| Moodle setting | Value |
| --- | --- |
| Tool / target link URL | `https://torus.test/lti/launch` |
| Initiate login URL | `https://torus.test/lti/login` |
| Redirection URI | `https://torus.test/lti/launch` |
| Public key type | Keyset URL |
| Public keyset URL | `https://torus.test/.well-known/jwks.json` |

Obtain the client ID, deployment ID, authorization URL, and token URL from
Moodle's external-tool configuration. In Torus, create an institution,
registration, and deployment using the
[manual registration instructions](config.md#manual-lti-13-configuration-in-torus-torus-admin).
Use issuer `https://moodle.test:8443` and keyset URL
`https://moodle.test:8443/mod/lti/certs.php`. Copy the remaining values exactly
from Moodle, including the authorization server/audience value it supplies.

## Verify the connection

From the Torus root with the environment above loaded, verify the actual LTI client:

```sh
mix run -e 'client = Lti_1p3.Config.http_client!(); {:ok, %{status_code: 200, body: body}} = client.get("https://moodle.test:8443/mod/lti/certs.php"); %{"keys" => keys} = Jason.decode!(body); IO.puts("Moodle JWKS verified: #{length(keys)} keys")'
```

Open `https://torus.test/.well-known/jwks.json` in the browser and confirm there is
no certificate warning. Moodle must also reach this URL from its PHP container
with TLS verification enabled.

Add the registered external tool to a Moodle course and launch as an instructor
to create/link a Torus section. Then launch as a student and verify access to the
same section. Enable Moodle's roster and grade service permissions to test roster
sync and grade passback. Use a new window if browser third-party cookie settings
block an embedded launch.

An `unknown_ca` error indicates missing outbound CA trust; hostname errors indicate
the URL does not match the certificate. Connection refusals indicate a stopped
listener, incorrect port, or Docker hostname routing. Registration errors require
checking the exact issuer, client ID, and deployment ID on both sides.
