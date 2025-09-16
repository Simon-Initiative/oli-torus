# Developing Torus with Claude Code

## MCP Support

### Tidewave

Torus has Tidewave installed and enabled for the development environment.  To add Tidewave MCP to
Claude Code:

```
claude mcp add --transport sse tidewave https://localhost/tidewave/mcp
```

### AppSignal

Claude Code can use the AppSignal MCP server to peruse error and performance data from our AppSignal
instances.

1. Generate an AppSignal MCP token for a server using the AppSignal Web UI.
2. Add the AppSignal MCP server to Claude Code:

```
claude mcp add appsignal -e APPSIGNAL_API_KEY=your-mcp-token -- docker run -i --rm -e APPSIGNAL_API_KEY appsignal/mcp
```

NOTE: Make sure that you have Docker installed and it is running, otherwise you will get a silent failure

### Torus MCP Server

Torus provides its own MCP Server that provides a set of tools and resources that allow an external
agent like Claude Code to author course content.

To add it:

1. Generate a Bearer Token for an author and a project using the Torus UI from Project Overview.
2. Add the MCP server to Claude Code

```
claude mcp add --scope user --transport http torus http://localhost/mcp --header "Authorization: Bearer your-token"
```

NOTE: This connection seems flaky and eventually Claude Code will report that it is no longer connected.
The root cause for this (which also seems to affect Tidewave) might be our SSL self-cert.  Current
recommendation is start Claude Code telling it to trust this cert.  One way to do that (assuming you are launching Claude Code from within the `devmode.sh` environment so that it can successfully run tests) is to add this to your `oli.env`:

```
NODE_EXTRA_CA_CERTS=/your/full/path/priv/ssl/localhost.crt
alias c='claude --dangerously-skip-permissions'
```

Restarting your machine seems to also fix these "localhost" connection problems.

### Verification

To verify that your MCP servers are connected and working do:

```
claude mcp list
```
