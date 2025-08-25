## Torus Overview
Learning engineering platform for authoring, delivering and improving online courses. Traditional monolithic Elixir/Phoenix app with
React frontend.

## Essential Commands
```bash
# Backend
set -a && source oli.env  # to properly set environment for other commands
mix deps.get && mix phx.server # install & run
mix test # test
mix test test/path/to/file.exs # run one test
mix format # format code
mix ecto.reset # reset DB

# Frontend (in assets/)
yarn install && yarn test # install & test
```

## Architecture

- Backend (lib/oli/): Authoring, Delivery, Activities, Resources, Publishing, LTI, Accounts
- Web (lib/oli_web/): Controllers, LiveViews, API, Plugs
- Frontend (assets/src/): apps/, components/, activities/, hooks/, state/

## Users

- Authors (%Author{})
- Instructors (%User{} with ContextRole of Instructor)
- Students (%User{} with ContextRole of Learner)
- Administrators (%Author{} with admin privs)

## Domain

- Authors create projects, add and edit resources, publish project
- Resource types: containers, pages, learning objectives, activities, tags
- Containers define structure by embedding references to pages and other containers
- Pages embed rich content, groups, examples, and most importantly activities
- Pages are either practice or scored (aka assessments)
- Activities target learning objectives
- Instructors create sections, customize material, enroll students, manage progress, grade questions
- Students navigate course, work practice pages, take assessments

## Key Patterns:

- Projects can share Resources
- Revision polymorphism (one table for all resource types)
- Publication model insures forward authoring without interferring with revisions pinned to sections
- Course sections customization via SectionResource
- Activity framework for defining new client-side impl activities
- LTI 1.3 support for LMS integration, with LTI gradepassback

## Common Development Tasks

### Adding a New LiveView
1. Create LiveView module in `lib/oli_web/live/`
2. Add route in `lib/oli_web/router.ex`
3. Define additional function components in LiveView, do not use external templates
4. Add tests in `test/oli_web/live/`

Consult this example: `lib/oli_web/live/admin/external_tools/details_view.ex`

### LiveView Tables

Reusable `PagedTable` and `SortableTableModel` components exist
to build sortable, searchable, paged tables.

Consult this example: `lib/oli_web/live/admin/external_tools/usage_view.ex`

### CSV Export Pattern

For adding CSV export functionality to existing tables:

1. **Data Layer**: Add export function to context module (e.g., `browse_projects_for_export/3`)
   - Remove pagination limits while preserving filtering/sorting
   - Reuse existing query logic for consistency

2. **Controller**: Create export action following PageDeliveryController pattern
   - Extract table state from URL parameters
   - Handle default values for admin preferences (show_all, show_deleted)
   - Use `send_download(conn, {:binary, csv_content}, filename: filename)`
   - Filename format: `resource-YYYY-M-D.csv`

3. **LiveView Integration**: Add export button and event handler
   - Button redirects to controller endpoint with current table state
   - Use `redirect(socket, external: export_url)` to trigger download

4. **CSV Formatting**:
   - Escape all fields with `escape_csv_field/1`
   - Use simple date format (YYYY-MM-DD) to avoid comma issues
   - Handle special characters, quotes, and newlines properly

Example files:
- Context: `lib/oli/authoring/course.ex:browse_projects_for_export/3`
- Controller: `lib/oli_web/controllers/projects_controller.ex:export_csv/2`
- LiveView: `lib/oli_web/live/projects/projects_live.ex` (export_csv event)

## Critical Performance Rules

- Use SectionResourceDepot cache, not SectionResource queries
- Never use DeliveryResolver.full_hierarchy directly
- Avoid cross-table queries in attempt hierarchy tables

## Dev Guidelines

- Use `IO.inspect` for Elixir debugging
- All new UIs should use LiveView not React
- Use Tailwind for CSS
- Respect publication model (immutable once published)
- Use AuthoringResolver/DeliveryResolver for revision lookup
- Oban for durable background jobs
- Test with ExUnit (backend) and Jest (frontend)
- Format code before committing

## Additional Design Docs

Consult when necessary:

- guides/design/attempt-handling.md: Attempt processing
- guides/design/publication-model.md: Publication model
- guides/design/genai.md: GenAI infrastructure