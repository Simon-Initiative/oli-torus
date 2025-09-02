# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OLI Torus is a sophisticated learning engineering platform built with Elixir/Phoenix (backend) and TypeScript/React (frontend). It provides course authoring and delivery capabilities with tight LMS integration via LTI 1.3.

## Essential Commands

### Backend (Elixir/Phoenix)

```bash
# Install dependencies
mix deps.get

# Run development server
mix phx.server

# Run tests
mix test

# Run specific test file
mix test test/path/to/test_file.exs

# Format code
mix format

# Reset database
mix ecto.reset
```

### Frontend (TypeScript/React)

```bash
# Navigate to assets directory first
cd assets

# Install dependencies
yarn install

# Run tests
yarn test

# Run specific test
yarn test path/to/test

# Format code
yarn format
```

## High-Level Architecture

### Backend Structure (Elixir/Phoenix)

The backend follows Phoenix context pattern with clear separation of concerns:

#### Core Contexts (`lib/oli/`)
- **Authoring**: Project management, collaboration, content creation
- **Delivery**: Section management, student progress, grading
- **Activities**: Extensible activity framework with registration system
- **Resources**: Content versioning with resource/revision pattern
- **Publishing**: Publication and deployment workflow
- **LTI**: LTI 1.3 integration for LMS connectivity
- **Accounts**: User and author management

#### Web Layer (`lib/oli_web/`)
- **Controllers**: Traditional HTTP endpoints
- **LiveViews**: Real-time interactive UI components
- **API**: REST endpoints for frontend integration
- **Plugs**: Middleware for auth, authorization, request processing

### Frontend Structure (TypeScript/React)

Located in `assets/src/`:

- **apps/**: Main application entry points (AuthoringApp, DeliveryApp, etc.)
- **components/**: Reusable UI components
- **components/activities/**: Activity type implementations
- **hooks/**: Phoenix hooks and React custom hooks
- **state/**: Redux state management
- **phoenix/**: Phoenix/LiveView integration code

### Key Architectural Patterns

1. **Resource/Revision Pattern**: All content is versioned through resources (containers) and revisions (specific versions)
2. **Publication Model**: Projects are published to create immutable publications, which are then deployed to sections
3. **Activity Framework**: Plugin-based system for adding new activity types via manifests
4. **Multi-tenancy**: Institution-based data separation with proper authorization
5. **Phoenix Clustering**: Horizontal scaling with distributed Erlang

## Database Schema

PostgreSQL with Ecto ORM. Key tables:
- `projects`: Course authoring projects
- `sections`: Course delivery instances
- `resources` & `revisions`: Versioned content
- `activities`: Activity configurations
- `users` & `authors`: Account management
- `enrollments`: Student-section relationships
- `attempts`: Student activity attempts

## Activity Development

Activities are self-contained components with:
- Manifest file defining metadata
- Authoring component (React)
- Delivery component (React)
- Model schema (JSON)
- Evaluation logic

Example activity types: Multiple Choice, Short Answer, File Upload, Multi-Input, etc.

## Testing Approach

- **Backend**: ExUnit tests in `test/` directory
- **Frontend**: Jest tests alongside source files
- Use factories for test data generation
- Integration tests for critical workflows
- Always run tests before committing

## Common Development Tasks

### Adding a New Page/LiveView
1. Create LiveView module in `lib/oli_web/live/`
2. Add route in `lib/oli_web/router.ex`
3. Create corresponding templates if needed
4. Add tests in `test/oli_web/live/`

### Modifying Activities
1. Update activity manifest in `assets/src/components/activities/[activity_type]/`
2. Modify authoring/delivery components
3. Update model schema if needed
4. Test both authoring and delivery modes

### Working with Resources/Content
1. Use `Oli.Resources` context for content operations
2. Always work with revisions, not resources directly
3. Respect the publication model - don't modify published content
4. Use proper authorization checks

## Important Considerations

- **LTI Context**: Many features depend on LTI launch context from LMS
- **Multi-tenancy**: Always scope data by institution/section
- **Versioning**: Content is immutable once published
- **Real-time Updates**: Use Phoenix PubSub for real-time features
- **Background Jobs**: Use Oban for async processing
- **Caching**: Leverage Cachex for performance-critical paths

## Code Style Guidelines

- Follow Elixir formatting standards (use `mix format`)
- TypeScript code uses ESLint configuration
- React components should be functional with hooks
- Prefer composition over inheritance
- Keep contexts focused and cohesive
- Rarely use "if", prefer "case" statements
- Use the "with" construct to avoid nested "case" statements

## Debugging Tips

- Use `IO.inspect` for Elixir debugging
- Browser DevTools for React debugging
- Phoenix LiveDashboard at `/admin/live_dashboard` (dev mode)
- Check `assets/webpack.config.js` for frontend build configuration
- Database queries can be inspected with Ecto query logging