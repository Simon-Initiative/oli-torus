# Bearer Token Authentication for Torus MCP Server - Implementation Plan

Based on my analysis of the current codebase, here's a comprehensive plan to add Bearer token authentication support to the Torus MCP server, including refactoring the MCP implementation to a more appropriate context.

## Current State Analysis

### Existing ApiKey Infrastructure
- **Schema**: `Oli.Interop.ApiKey` stores MD5 hashes of API keys (not the raw keys)
- **Table**: `api_keys` with fields: `status`, `hash`, `hint`, scope flags (`payments_enabled`, `products_enabled`, etc.)
- **Authentication**: Bearer token pattern already implemented in `OliWeb.Api.Helpers.is_valid_api_key?/2`
- **Validation**: Base64 encoding/decoding with MD5 hash comparison

### MCP Server Architecture
- **Current Location**: Incorrectly placed under `Oli.GenAI` module namespace
- **Server**: `Oli.GenAI.MCPServer` using Hermes v0.14.1
- **Authentication**: Currently **no authentication** mechanism implemented
- **Tools**: 6 registered tools for content manipulation and validation
- **Transport**: Streamable HTTP transport in application supervisor

### Project Overview Page Structure
- **LiveView**: `OliWeb.Workspaces.CourseAuthor.OverviewLive`
- **Sections**: Multiple Overview.section components for different configuration areas
- **Location**: Perfect spot for new "MCP Access Tokens" section after existing sections

## Implementation Plan

### Phase 0: Refactor MCP Implementation (NEW)

#### 0.1 Create New MCP Context Structure
Move all MCP-related code from `Oli.GenAI` to new `Oli.MCP` context:

```
lib/oli/mcp/
├── server.ex                 # Main MCP server (from Oli.GenAI.MCPServer)
├── auth.ex                    # New authentication context
├── auth/
│   └── bearer_token.ex        # Bearer token schema
├── tools/
│   ├── revision_content_tool.ex
│   ├── activity_validation_tool.ex
│   ├── activity_test_eval_tool.ex
│   ├── example_activity_tool.ex
│   ├── create_activity_tool.ex
│   └── content_schema_tool.ex
```

#### 0.2 Update Module References
- Update all imports/aliases from `Oli.GenAI.Tools.*` to `Oli.MCP.Tools.*`
- Update `Oli.GenAI.MCPServer` references to `Oli.MCP.Server`
- Update application supervisor to reference new module location
- Update tests to use new module paths

#### 0.3 Keep Agent Components Separate
- Leave `Oli.GenAI.Agent.*` modules in place (they're separate from MCP)
- Update `MCPToolRegistry` references if needed

### Phase 1: Database Schema & Context

#### 1.1 Create MCP Bearer Token Schema
```elixir
# New table: mcp_bearer_tokens
- id (primary key)
- author_id (FK to authors, NOT NULL)
- project_id (FK to projects, NOT NULL)
- hash (binary, MD5 hash of token, NOT NULL)
- hint (string, user description)
- status (enum: enabled/disabled, default: enabled)
- last_used_at (timestamp, nullable)
- created_at, updated_at

# Unique constraint on (author_id, project_id)
# Index on hash for fast lookups
```

#### 1.2 Create Auth Context Module
```elixir
# lib/oli/mcp/auth.ex
defmodule Oli.MCP.Auth do
  # Token management
  - create_token(author_id, project_id, hint)
  - get_token_by_author_and_project(author_id, project_id)
  - regenerate_token(author_id, project_id, hint)
  - delete_token(id)
  
  # Validation
  - validate_token(token) -> {:ok, %{author_id, project_id}} | {:error, reason}
  - validate_project_access(token, project_slug)
  
  # Queries
  - list_tokens_for_author(author_id)
  - list_tokens_for_project(project_id)
  - update_last_used(token_hash)
end
```

### Phase 2: Authentication Integration

#### 2.1 MCP Server Authentication Middleware
Create new plug: `OliWeb.Plugs.ValidateMCPBearerToken`
```elixir
defmodule OliWeb.Plugs.ValidateMCPBearerToken do
  # Extract Bearer token from Authorization header
  # Validate token and set conn assigns:
  #   - mcp_authenticated: true/false
  #   - mcp_author_id: author_id
  #   - mcp_project_id: project_id
end
```

#### 2.2 Update MCP Server
Modify `Oli.MCP.Server` to:
- Add authentication requirement configuration
- Pass authentication context to tools
- Handle unauthenticated requests appropriately

#### 2.3 Tool Authorization Enhancement
Update each tool in `Oli.MCP.Tools.*` to:
- Accept authentication context in execute/2
- Validate project access before operations
- Return proper authorization errors

### Phase 3: UI Implementation

#### 3.1 Project Overview Section
Add new section to `overview_live.ex` after "Advanced Activities":
```heex
<Overview.section 
  title="MCP Access Tokens" 
  description="Generate Bearer tokens for external AI agents to access this project's content via the Model Context Protocol (MCP).">
  <.live_component
    module={OliWeb.Projects.MCPTokenManager}
    id="mcp-token-manager"
    project={@project}
    current_author={@current_author}
  />
</Overview.section>
```

#### 3.2 Token Management LiveComponent
Create `OliWeb.Projects.MCPTokenManager`:
- Display existing token status (enabled/disabled)
- Show masked token hint if exists
- "Generate New Token" button (first time)
- "Regenerate Token" button (replaces existing)
- Modal to display full token on generation (one-time view)
- Copy-to-clipboard functionality
- Token enable/disable toggle
- Last used timestamp display

### Phase 4: Security Enhancements

#### 4.1 Token Generation
```elixir
defmodule Oli.MCP.Auth.TokenGenerator do
  # Generate cryptographically secure random token
  # Format: "mcp_" <> Base.url_encode64(:crypto.strong_rand_bytes(32))
  # Store MD5 hash in database
  # Return full token only on generation
end
```

#### 4.2 Access Control Rules
- One active token per author/project combination
- Tokens grant read/write access to specific project only
- Cannot access other projects or cross-project resources
- Token operations require author to be project collaborator

### Phase 5: Router & Endpoint Configuration

#### 5.1 Update Router
```elixir
# lib/oli_web/router.ex
pipeline :mcp_api do
  plug :accepts, ["json"]
  plug OliWeb.Plugs.ValidateMCPBearerToken
end

scope "/mcp", OliWeb do
  pipe_through :mcp_api
  # MCP endpoints here
end
```

### Phase 6: Testing & Documentation

#### 6.1 Migration Scripts
```elixir
# priv/repo/migrations/*_create_mcp_bearer_tokens.exs
- Create table with proper constraints
- Add indexes for performance
- Set up foreign key cascades
```

#### 6.2 Test Coverage
- Unit tests for `Oli.MCP.Auth` context
- Integration tests for MCP authentication flow
- LiveView tests for token management UI
- Security tests for authorization boundaries
- Test token regeneration and invalidation

#### 6.3 Documentation
- Add MCP authentication docs to project README
- Document token generation process
- API usage examples with Bearer tokens

## Implementation Order

1. **Phase 0: Refactor MCP to new context** (CRITICAL FIRST STEP)
   - Move all MCP code from `Oli.GenAI` to `Oli.MCP`
   - Update all references and imports
   - Run tests to ensure nothing breaks

2. **Database Migration**
   - Create `mcp_bearer_tokens` table
   - Add proper indexes and constraints

3. **Auth Context Implementation**
   - Implement `Oli.MCP.Auth` module
   - Add token generation and validation

4. **Authentication Middleware**
   - Create Bearer token validation plug
   - Integrate with MCP server

5. **Tool Authorization**
   - Update each tool to check project access
   - Add proper error responses

6. **UI Implementation**
   - Add token manager to project overview
   - Implement token generation/display flow

7. **Testing**
   - Comprehensive test coverage
   - Security testing

8. **Documentation**
   - Usage documentation
   - API reference

## Files to Create/Modify

### Phase 0: Refactoring (Move/Rename)
- `lib/oli/gen_ai/mcp_server.ex` → `lib/oli/mcp/server.ex`
- `lib/oli/gen_ai/tools/*` → `lib/oli/mcp/tools/*`
- Update `lib/oli/application.ex` supervisor reference
- Update `lib/oli/gen_ai/agent/mcp_tool_registry.ex` references

### New Files
- `lib/oli/mcp/auth.ex` - Authentication context
- `lib/oli/mcp/auth/bearer_token.ex` - Token schema
- `lib/oli/mcp/auth/token_generator.ex` - Token generation
- `lib/oli_web/plugs/validate_mcp_bearer_token.ex` - Auth plug
- `lib/oli_web/live/projects/mcp_token_manager.ex` - UI component
- `priv/repo/migrations/*_create_mcp_bearer_tokens.exs` - Migration

### Modified Files
- `lib/oli_web/router.ex` - Add MCP API pipeline
- `lib/oli_web/live/workspaces/course_author/overview_live.ex` - Add UI section
- All test files for moved modules

## Security Considerations

- Use cryptographically secure token generation
- Store only MD5 hashes (following existing pattern)
- One token per author/project pair
- Clear token display only once on generation
- Audit logging for token operations
- Automatic token invalidation on project/author removal
- Rate limiting on token validation endpoints

## Benefits of Refactoring

1. **Better Organization**: MCP is not AI-specific, it's a protocol for tools
2. **Clearer Boundaries**: Separates MCP server from AI agent implementation
3. **Easier Maintenance**: All MCP code in one context
4. **Logical Structure**: Auth naturally fits under MCP context
5. **Future Extensibility**: Easy to add more MCP features

This revised plan ensures proper code organization while adding robust authentication to the MCP server implementation.