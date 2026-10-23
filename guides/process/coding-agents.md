# Developing Torus with Coding Agents

Codex, Claude Code, and other MCP-compatible coding agents can connect to Torus development
services. Follow `AGENTS.md` for repository rules and `docs/TOOLING.md` for development commands.

## Shared MCP setup

Model Context Protocol (MCP) lets an agent call tools and read resources exposed by a server.
Choose the services needed for your task:

| Service | Purpose | Connection |
| --- | --- | --- |
| Torus Authoring MCP | Read project content and use authoring tools | Streamable HTTP at `/mcp`, with a project-scoped Bearer token |
| Tidewave | Inspect and interact with the running development application | Streamable HTTP at `/tidewave/mcp`, enabled in development |
| AppSignal | Inspect errors and performance data | Local stdio process using Docker and an AppSignal MCP token |

Start Torus before connecting to its HTTP endpoints. The examples use the default local HTTP
address, `http://localhost`; adjust the scheme, host, and port for your environment. The agent's
MCP client must be able to reach that address. In a remote environment, `localhost` refers to
that environment.

For Torus Authoring MCP, generate a token for your author and project from Project Overview.
Make it available as `TORUS_MCP_TOKEN` in the environment that launches your agent. For AppSignal,
generate an MCP token in the AppSignal web UI, make it available as `APPSIGNAL_API_KEY`, and ensure
Docker is running. Keep actual credentials out of repository files.

Torus resource discovery uses `resources/templates/list`. The seven project templates cover
metadata, hierarchy, the objectives graph, and individual pages, activities, containers, and
objectives. Read a concrete URI with `resources/read`, for example
`torus://p/<project_slug>/hierarchy`. Include the project-scoped Bearer token on each request;
a token for one project cannot read another project's content.

## Codex setup

Register Torus and, optionally, Tidewave with the Codex CLI:

```sh
codex mcp add torus --url http://localhost/mcp --bearer-token-env-var TORUS_MCP_TOKEN
codex mcp add tidewave --url http://localhost/tidewave/mcp
```

Ensure `TORUS_MCP_TOKEN` is available to the Codex process when it connects. Setting it in an
unrelated terminal does not update an already-running application.

For AppSignal, add this entry to your user configuration at `~/.codex/config.toml`. It forwards
`APPSIGNAL_API_KEY` from the Codex process environment to Docker:

```toml
[mcp_servers.appsignal]
command = "docker"
args = ["run", "-i", "--rm", "-e", "APPSIGNAL_API_KEY", "appsignal/mcp"]
env_vars = ["APPSIGNAL_API_KEY"]
```

Inspect configured servers with:

```sh
codex mcp list
codex mcp get torus
```

Use `/mcp` in the Codex terminal interface to inspect active connections. See the
[official Codex MCP documentation](https://developers.openai.com/codex/mcp) for configuration
locations and additional options.

## Claude Code setup

Register Torus and, optionally, Tidewave:

```sh
claude mcp add --scope user --transport http torus http://localhost/mcp --header "Authorization: Bearer ${TORUS_MCP_TOKEN}"
claude mcp add --scope user --transport http tidewave http://localhost/tidewave/mcp
```

The shell expands `TORUS_MCP_TOKEN` when this command runs, so the Torus entry stores the current
token value. Update that entry after rotating the token.

For AppSignal:

```sh
claude mcp add --scope user --transport stdio --env "APPSIGNAL_API_KEY=${APPSIGNAL_API_KEY}" appsignal -- docker run -i --rm -e APPSIGNAL_API_KEY appsignal/mcp
```

Inspect configured servers with `claude mcp list` and active connections with `/mcp` inside
Claude Code. See the [Claude Code MCP documentation](https://code.claude.com/docs/en/mcp) for
configuration scopes and authentication options.

## Other coding agents

Configure Torus and Tidewave as Streamable HTTP servers using the endpoints above. For Torus,
configure the `Authorization: Bearer <token>` header. For AppSignal, configure a stdio server
that runs `docker run -i --rm -e APPSIGNAL_API_KEY appsignal/mcp`, with `APPSIGNAL_API_KEY` supplied
to the process. Consult your agent's documentation for its configuration format.

## Verify the connection

A configured server entry alone does not prove that resource reads work. After connecting,
ask the agent to perform these checks against Torus Authoring MCP:

1. List tools and resource templates. Confirm that all seven project templates are present.
2. Read `torus://p/<project_slug>/hierarchy` using the token's project slug.
3. Read a page URI returned by that hierarchy and confirm that it contains the expected content.
4. Attempt a read using another project's slug and confirm that access is rejected.

## Troubleshooting

- **Template discovery fails:** Anubis 0.13.1 rejected `resources/templates/list` before Torus
  could handle it. This checkout uses Anubis 0.14.1. Run `mix deps.get` and restart Torus after
  updating the checkout, then retry discovery.
- **Project reads fail:** Check that the token is active, its author still has project access,
  the URI identifies the token's project, and the client sends the token on each request.
- **Cannot connect:** Confirm that Torus is running and that the client can reach the configured
  scheme, host, and port. Use Streamable HTTP for Tidewave; its current endpoint does not support
  the older SSE transport. See [Tidewave MCP setup](https://hexdocs.pm/tidewave/mcp.html).
- **HTTPS certificate error:** Configure certificate trust for the client making the connection.
  Diagnose the reported TLS error before changing trust settings. Use your client's documented
  trust configuration; certificate settings are specific to the client runtime.
- **AppSignal fails to start:** Confirm that Docker is running and that `APPSIGNAL_API_KEY` reaches
  the container.

For intermittent failures, capture the client's error and the corresponding Torus logs to
identify whether the failure occurs during connection, initialization, discovery, or a resource read.
