# Elixir Review Checklist (`elixir.md`)

> Use this during PR review to spot correctness, maintainability, performance, and security issues in Elixir/Phoenix/Ecto/LiveView code. Leave **specific, actionable** comments (file:line + suggested fix). Keep the code simple, explicit, and idiomatic.

---

## Review Scope & Workflow
- [ ] **Scope the review to the diff**: run `git diff` and review **only changed files** plus touched dependencies.
- [ ] **Summarize findings** as actionable steps with file & line references (e.g., “Replace `if` with `case` at `path/to/file.ex:24`”).
- [ ] Prefer concrete suggestions over vague remarks.

**Good examples**
- Remove duplicate code at `file.ex:234`.
- Replace SectionResource query with `SectionResourceDepot` at `other_file.ex:23`.
- Replace `if` construct with `case` at `path/to/file.ex:24`.

**Bad examples**
- “Poorly named functions everywhere.”
- “Needs more tests.”

---

## General Considerations
- [ ] Code is **simple and readable**; minimal cleverness.
- [ ] Functions/variables **well named**; modules cohesive.
- [ ] **No duplication**; extract helpers/composables.
- [ ] **Explicit error handling** (`{:ok, _} | {:error, _}`); avoid exceptions for control flow.
- [ ] **No secrets** in code/config/history.
- [ ] **Validate inputs** at boundaries.
- [ ] **Adequate tests** (unit/integration); cover edge cases.
- [ ] **Performance** considerations are addressed (no N+1, no queries in loops, bounded concurrency).

---

## Torus Architecture Considerations
- [ ] No cyclic dependencies between modules; no `Oli` code using `OliWeb` code.
- [ ] Modules/contexts/components are **logically organized**; opportunities for reuse noted.
- [ ] **Performance & Scalability**
  - Prefer **one tailored query** instead of multiple reused queries when feasible.
  - If a single query becomes planner-hostile, **split into simpler queries**.
  - Prefer **aggregated tables** (`ResourceSummary`, `ResponseSummary`) over scanning `ActivityAttempt`/`PartAttempt`.
  - **Delivery code uses `SectionResourceDepot`** for page titles, hierarchy, schedules, page details (do not hand-roll resolver queries).
  - LiveViews **optimize TTFB** via **async assigns**; assigns contain only what’s needed to render.

---

## Elixir Language Best Practices

### Control flow & data handling
- [ ] Prefer **pattern matching** and **guards** over nested conditionals.
- [ ] Use **`case`/`cond`** for multi-branch logic; **Elixir does not support `else if`**.
- [ ] **Never** use index-based access on lists (`list[i]` is invalid); use `Enum.at/2`, pattern matching, or `List` module.
- [ ] Bind expression results to variables; do **not** rebind inside `if/case/cond` without assigning:
```elixir
# Bad
if connected?(socket), do: socket = assign(socket, :val, val)

# Good
socket =
  if connected?(socket) do
    assign(socket, :val, val)
  else
    socket
  end
```
- [ ] Use **`with`** to chain functions returning `{:ok, _} | {:error, _}` for linear happy paths.

### Immutability & API shape
- [ ] Prefer **pure functions**; avoid hidden side effects.
- [ ] Return **tuples** for outcomes; avoid raising on expected failures.
- [ ] Predicate function names **end with `?`**, not `is_` (reserve `is_*` for guards).

### Data structures & access
- [ ] **Do not** use map access (`struct[:field]`) on structs (no Access behavior). Use `struct.field` or APIs like `Ecto.Changeset.get_field/2`.
- [ ] Avoid `String.to_atom/1` on user input (atom table DoS). Use whitelists or keep as strings.

### Time & dates
- [ ] Use **`Time`/`Date`/`DateTime`/`Calendar`** from stdlib. Only add deps for parsing if truly needed (e.g., `date_time_parser`).

### Modules & files
- [ ] **One top-level module per file**; avoid nesting multiple modules in one file (prevents cycles/compilation issues).
- [ ] Document public functions; consider `@doc` and `@moduledoc`.

### Concurrency & I/O
- [ ] **Do not block GenServers** with DB/HTTP/CPU work (offload to `Task` or worker processes).
- [ ] Prefer **`Task.async_stream/3`** with **bounded concurrency** and `timeout: :infinity` (or explicit timeout) to apply back-pressure.
- [ ] Consider **iodata** for building large strings/binaries efficiently.

---

## OTP & Supervision
- [ ] Child specs **named**: `{DynamicSupervisor, name: MyApp.MyDynamicSup}`; start via `DynamicSupervisor.start_child/2`.
- [ ] Pick correct supervisor strategy (`:one_for_one`, etc.) and restart intensities.
- [ ] Use **`Registry`** for process lookup; avoid global state.
- [ ] Long-lived processes expose a **clear API**; avoid passing PIDs around arbitrarily.

---

## Mix & Tooling
- [ ] `mix help <task>` before usage; avoid cargo-culting.
- [ ] Test targeting: `mix test test/my_test.exs` and `mix test --failed` for quick iterations.
- [ ] `mix deps.clean --all` is **almost never needed**.
- [ ] Enforce code style: `mix format`, `Credo` clean (readability prevents bugs).
- [ ] Security lint: `Sobelow` findings reviewed or documented.
- [ ] Consider Dialyzer (typespecs) for critical modules.

---

## Phoenix: Router & Conventions
- [ ] Router `scope` aliasing is understood; avoid duplicate module prefixes.
- [ ] **Do not** use `Phoenix.View` (removed in modern Phoenix).
- [ ] Prefer `<.link navigate|patch>` and `push_navigate|push_patch` over deprecated `live_redirect/patch`.

**Route aliasing reminder**
```elixir
scope "/admin", AppWeb.Admin do
  pipe_through :browser
  live "/users", UserLive, :index
end
# → AppWeb.Admin.UserLive
```

---

## Ecto Guidelines
- [ ] Preload associations used by templates/controllers to avoid N+1.
- [ ] Import `Ecto.Query` and helpers in data seeds or query modules.
- [ ] Schema fields: `:string` type is used for textual DB columns (covers `VARCHAR`/`TEXT`).
- [ ] `Ecto.Changeset.validate_number/3` does **not** need `:allow_nil`; validations only run on present, non-nil changes.
- [ ] Access changeset fields via **`Ecto.Changeset.get_field/2`**.
- [ ] Server-set fields (e.g., `user_id`) are **not** cast from params; set explicitly in code.
- [ ] Avoid multiple small queries; prefer set-based ops (`insert_all/3`, `update_all/3`) where appropriate.
- [ ] For large reads, **stream** within a transaction: `Repo.stream/2`.

---

## Phoenix HTML / HEEx
- [ ] Use **`~H`** or `.html.heex` templates; never `~E`.
- [ ] Use **`Phoenix.Component.form/1`** and **`Phoenix.Component.inputs_for/1`**; do **not** use `Phoenix.HTML.form_for/inputs_for` (outdated).
- [ ] Build forms via **`to_form/2`** in LiveView; access as `@form[:field]` in templates.
- [ ] **Unique DOM IDs** for key elements (forms, buttons) to aid tests.
- [ ] Shared template imports/aliases go in `my_app_web.ex` under `html_helpers`.
- [ ] Literal `{`/`}` blocks require **`phx-no-curly-interpolation`**:
```heex
<code phx-no-curly-interpolation>
  let obj = {key: "val"}
</code>
```
- [ ] HEEx `class` attribute **uses lists**; wrap conditional classes in `[...]` and wrap inline `if(...)` with parens:
```heex
<a class={[
  "px-2 text-white",
  @some_flag && "py-5",
  if(@other_condition, do: "border-red-500", else: "border-blue-100")
]}>
  Text
</a>
```
- [ ] **Never** use `<% Enum.each %>` to generate content; use a **for-comprehension**:
```heex
<%= for item <- @collection do %>
  ...
<% end %>
```
- [ ] HEEx comments: `<%!-- comment --%>`.
- [ ] Attribute interpolation uses `{...}`; **block constructs** go in `<%= ... %>` **inside tag bodies**.

---

## Phoenix LiveView
- [ ] Avoid LiveComponents unless necessary (prefer function components/slots).
- [ ] Name LiveViews like `AppWeb.ThingLive`.
- [ ] If a custom JS hook manages its own DOM (`phx-hook="X"`), set **`phx-update="ignore"`**.
- [ ] **No inline `<script>`** in HEEx; place code in `assets/js` and import via `assets/js/app.js`.

### Async Assigns & TTFB
- [ ] Use **`assign_async`** to load slow data in parallel; reduce initial render latency.
- [ ] Keep `socket.assigns` minimal—only what’s needed to render.

### Streams (memory-safe collections)
- [ ] Use **streams** for lists to avoid memory ballooning:
  - append: `stream(socket, :messages, [new_msg])`
  - reset: `stream(socket, :messages, new_msgs, reset: true)`
  - prepend: `stream(socket, :messages, [new_msg], at: -1)`
  - delete: `stream_delete(socket, :messages, msg)`
- [ ] Template must set **`phx-update="stream"`** and use `@streams.name`:
```heex
<div id="messages" phx-update="stream">
  <div :for={{id, msg} <- @streams.messages} id={id}>
    {msg.text}
  </div>
</div>
```
- [ ] **Do not** `Enum.filter` a stream; **re-fetch** and stream with `reset: true`.
- [ ] Streams don’t support counts/emptiness; track counts separately and provide empty states via markup.

### LiveView Tests
- [ ] Use `Phoenix.LiveViewTest` helpers; avoid brittle raw HTML assertions.
- [ ] Test forms with `render_submit/2`, `render_change/2`.
- [ ] Target elements by **IDs** you added in templates.
- [ ] Debug failing selectors by printing filtered HTML (e.g., using `LazyHTML`).

---

## Forms (LiveView)

### Creating from params
```elixir
def handle_event("submitted", params, socket) do
  {:noreply, assign(socket, form: to_form(params))}
end

# Named nested params
def handle_event("submitted", %{"user" => user_params}, socket) do
  {:noreply, assign(socket, form: to_form(user_params, as: :user))}
end
```

### Creating from changesets
```elixir
%MyApp.Users.User{}
|> Ecto.Changeset.change()
|> to_form()
# Form available as %{"user" => user_params} on submit
```

### Avoiding form errors
- [ ] Always drive templates with **`@form`** from `to_form/2`.
- [ ] **Do not** access a changeset directly in templates.
- [ ] **Do not** use `<.form let={f} ...>`; always `<.form for={@form} ...>`.
- [ ] Give each form a unique `id`.

---

## Project Guidelines
- [ ] Run `mix precommit` when finished and fix reported issues.
- [ ] Use bundled **`Req`** for HTTP; avoid `:httpoison`, `:tesla`, `:httpc` unless justified.

### Phoenix v1.8
- [ ] LiveView pages start with `<Layouts.app ...>` wrapper in templates.
- [ ] `MyAppWeb.Layouts` is already aliased via `my_app_web.ex`; no extra alias needed.
- [ ] If you see missing `current_scope`, fix router **live_session** placement and pass `current_scope` to layouts.
- [ ] `<.flash_group>` belongs in `Layouts`; do not call elsewhere.
- [ ] Use `<.icon>` from `core_components.ex`; do not import Heroicons modules directly.
- [ ] Prefer `<.input>` from `core_components.ex`; overriding classes requires fully styling.

### JS & CSS
- [ ] Tailwind v4 import style in `app.css`:
```css
@import "tailwindcss" source(none);
@source "../css";
@source "../js";
@source "../../lib/my_app_web";
```
- [ ] **No `@apply`** in raw CSS.
- [ ] Only `app.js` and `app.css` bundles are supported. Import vendor deps there.
- [ ] **No inline `<script>` tags** in templates.

### UI/UX (high level)
- [ ] Clean typography/spacing/layout; subtle micro-interactions; clear loading/empty/error states.

---

## Authentication (Router-first)
- [ ] Handle auth at the **router** with proper redirects.
- [ ] Use the generated **live sessions**:
  - `:current_user` (works with or without login): `on_mount: [{MyAppWeb.UserAuth, :mount_current_scope}]`
  - `:require_authenticated_user` (requires login): `on_mount: [{MyAppWeb.UserAuth, :ensure_authenticated}]`
- [ ] **Never duplicate** live session names; group routes correctly.
- [ ] Do **not** rely on `@current_user` in templates; access via `current_scope.user`.
- [ ] When encountering `current_scope` issues, re-check router sessions and layout usage.

**Auth-required routes example**
```elixir
scope "/", AppWeb do
  pipe_through [:browser, :require_authenticated_user]
  live_session :require_authenticated_user,
    on_mount: [{AppWeb.UserAuth, :ensure_authenticated}] do
    live "/secure", SecureLive
  end
end
```

**Routes that work with or without auth**
```elixir
scope "/", MyAppWeb do
  pipe_through [:browser]
  live_session :current_user,
    on_mount: [{MyAppWeb.UserAuth, :mount_current_scope}] do
    live "/", PublicLive
  end
end
```

---

## Reviewer Red Flags (paste as actionable comments)
- “Query inside `Enum.map`—batch into a single query or prefetch, `file.ex:NN`.”
- “Bypass of `SectionResourceDepot` in Delivery path—switch to cache.”
- “N+1 detected—add `preload` for associations used in template.”
- “Using `struct[:field]`—access as `struct.field` or via `Ecto.Changeset.get_field/2`.”
- “`String.to_atom/1` on user input—replace with whitelist or keep strings.”
- “Multiple modules in file—split to avoid cycles/compilation issues.”
- “Blocking work in GenServer—offload to `Task`/worker; keep callbacks fast.”
- “Form driven by changeset in template—use `to_form/2` and `@form[:field]`.”
- “HEEx `class` attr not using list syntax—wrap in `[...]` and parens for `if(...)`.”
- “Inline `<script>` in HEEx—move to `assets/js` and import via `app.js`.”

---

## Quick Verification Steps
- [ ] Grep for queries in loops; confirm single-query or streamed approach.
- [ ] `EXPLAIN` slow queries; attach plan changes.
- [ ] Confirm LiveView **async assigns** and **streams** used where appropriate.
- [ ] Router: verify route placement in correct **live_session** and pipelines.
- [ ] Run `Credo` and `Sobelow`; annotate any accepted findings.
- [ ] Confirm no `String.to_atom/1` on untrusted input.
- [ ] Ensure tests exist for error paths and auth/tenancy checks.

---

## Snippets

**`with` for success/error chaining**
```elixir
with {:ok, user} <- Users.fetch(id),
     {:ok, plan} <- Billing.fetch_plan(user),
     {:ok, sub}  <- Billing.subscribe(user, plan) do
  {:ok, sub}
else
  {:error, reason} -> {:error, reason}
end
```

**Bounded concurrency**
```elixir
Task.async_stream(items, &process/1, max_concurrency: System.schedulers_online(), timeout: :infinity)
|> Enum.to_list()
```

**Repo streaming**
```elixir
Repo.transaction(fn ->
  Repo.stream(from u in User, select: u.email)
  |> Stream.each(&send_newsletter/1)
  |> Stream.run()
end)
```

**Avoid list index access**
```elixir
# Bad
color = colors[i]

# Good
color = Enum.at(colors, i)
# or pattern match in a function clause / head
```

**HEEx class list**
```heex
<a class={[
  "btn px-3 py-2",
  @primary && "btn-primary",
  if(@danger, do: "btn-danger", else: "btn-neutral")
]}>
  Save
</a>
```

**LiveView stream + empty state**
```heex
<div id="tasks" phx-update="stream">
  <div class="hidden only:block">No tasks yet</div>
  <div :for={{id, task} <- @streams.tasks} id={id}>
    {task.name}
  </div>
</div>
```

**Changeset server-set fields (mass-assignment guard)**
```elixir
def changeset(post, params) do
  post
  |> cast(params, [:title, :body])
  |> put_change(:user_id, current_user_id) # set server-side
end
```

**Safe atom mapping**
```elixir
@kinds ~w[audio video image]a
def parse_kind(kind) when kind in @kinds, do: {:ok, kind}
def parse_kind(_), do: {:error, :invalid_kind}
```
