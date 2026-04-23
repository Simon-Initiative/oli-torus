defmodule OliWeb.Attempt.AttemptLive do
  import Ecto.Query, warn: false
  alias Oli.Repo

  use OliWeb, :live_view

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.SortableTable.StripedTable
  alias OliWeb.Common.Table.SortableTableModel
  alias OliWeb.Components.DesignTokens.Primitives.Button
  alias OliWeb.Delivery.Content.SelectDropdown
  alias OliWeb.Icons
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Sections.Mount
  alias Oli.Delivery.Attempts.PageLifecycle.Broadcaster
  alias OliWeb.Attempt.TableModel
  alias Oli.Delivery.Attempts.Core.{ActivityAttempt, ResourceAttempt}

  # CapiVariableTypes codes — must stay in sync with assets/src/adaptivity/capi.ts.
  @capi_type_number 1
  @capi_type_string 2
  @capi_type_array 3
  @capi_type_boolean 4
  @capi_type_enum 5
  @capi_type_math_expr 6
  @capi_type_array_point 7

  def set_breadcrumbs(type, section, guid) do
    type
    |> OliWeb.Sections.OverviewView.set_breadcrumbs(section)
    |> breadcrumb(section, guid)
  end

  def breadcrumb(previous, section, guid) do
    previous ++
      [
        Breadcrumb.new(%{
          full_title: "Debug Attempt",
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, section.slug, guid)
        })
      ]
  end

  def mount(%{"section_slug" => section_slug, "attempt_guid" => attempt_guid}, _session, socket) do
    # Admin-only; defense-in-depth in case the UI entry-point gate is ever bypassed.
    case Mount.for(section_slug, socket) do
      {:admin, _, _} = result ->
        if connected?(socket), do: Broadcaster.subscribe_to_attempt(attempt_guid)
        do_mount(result, attempt_guid, socket)

      {:error, e} ->
        Mount.handle_error(socket, {:error, e})

      {:user, _, _} ->
        Mount.handle_error(socket, {:error, :unauthorized})

      {:author, _, _} ->
        Mount.handle_error(socket, {:error, :unauthorized})
    end
  end

  defp do_mount({type, _, section}, attempt_guid, socket) do
    attempts =
      get_attempts(attempt_guid)
      |> Enum.map(fn a -> Map.put(a, :updated, false) end)
      |> attach_unique_ids()
      |> precompute_grouped_responses()

    expanded_rows = MapSet.new()
    expanded_parts = MapSet.new()
    %{valid_part_ids: valid_part_ids, row_part_ids: row_part_ids} = build_part_indexes(attempts)

    {:ok, model} = TableModel.new(attempts)
    model = build_expandable_table_model(model, expanded_rows, expanded_parts)

    {:ok,
     assign(socket,
       attempt_guid: attempt_guid,
       breadcrumbs: set_breadcrumbs(type, section, attempt_guid),
       table_model: model,
       total_count: Enum.count(attempts),
       updates: [],
       section: section,
       attempts: attempts,
       expanded_rows: expanded_rows,
       expanded_parts: expanded_parts,
       valid_part_ids: valid_part_ids,
       row_part_ids: row_part_ids
     )}
  end

  # Rebuilt on mount and PubSub to replace O(n) scans with O(log n) lookups.
  # row_part_ids also doubles as the row-existence guard for toggle_row.
  defp build_part_indexes(attempts) do
    valid_part_ids =
      attempts
      |> Enum.flat_map(fn a -> Enum.map(a.part_attempts, & &1.id) end)
      |> MapSet.new()

    row_part_ids =
      Map.new(attempts, fn a -> {a.unique_id, Enum.map(a.part_attempts, & &1.id)} end)

    %{valid_part_ids: valid_part_ids, row_part_ids: row_part_ids}
  end

  # "row_<id>" is the shared identity used by the chevron, row-click, expanded_rows
  # MapSet, and StripedTable's details-row lookup. All four must agree.
  defp attach_unique_ids(attempts) do
    Enum.map(attempts, fn a -> Map.put(a, :unique_id, "row_#{a.id}") end)
  end

  # Responses/feedback are immutable after persistence — cache the grouped form
  # and sort part_attempts once to skip both on every re-render.
  defp precompute_grouped_responses(attempts) do
    for attempt <- attempts do
      sorted_parts =
        for part <- Enum.sort_by(attempt.part_attempts, & &1.part_id) do
          part
          |> Map.put(:grouped_response, group_dotted_keys(part.response || %{}))
          |> Map.put(:grouped_feedback, group_dotted_keys(part.feedback || %{}))
        end

      %{attempt | part_attempts: sorted_parts}
    end
  end

  # Uses :id (not :resource_id) as the row identity because retakes share resource_id
  # but have distinct activity_attempt.id.
  defp build_expandable_table_model(model, expanded_rows, expanded_parts) do
    data =
      Map.merge(model.data, %{
        expandable_rows: true,
        expandable_rows_id_field: :id,
        expanded_rows: expanded_rows,
        expanded_parts: expanded_parts
      })

    %{model | data: data}
  end

  defp build_expandable_table_model(model, attempts, expanded_rows, expanded_parts) do
    %{model | rows: attempts}
    |> build_expandable_table_model(expanded_rows, expanded_parts)
  end

  def render(assigns) do
    ~H"""
    <div style="padding: 0.5rem 1rem; overflow-x: auto;">
      <StripedTable.render
        model={@table_model}
        sort="sort"
        select="toggle_row"
        details_render_fn={&render_row_details/2}
      />
    </div>
    """
  end

  # StripedTable calls this via a captured function ref, so incoming assigns lack
  # __changed__; build a fresh map — change tracking re-enters at each nested component.
  def render_row_details(assigns, row) do
    row_id = "row_#{row.id}"

    assigns = %{
      is_expanded: MapSet.member?(assigns.model.data.expanded_rows, row_id),
      row_id: row_id,
      parts: row.part_attempts,
      expanded_parts: assigns.model.data.expanded_parts
    }

    ~H"""
    <%= if @is_expanded do %>
      <div class="max-h-[65vh] overflow-y-auto">
        <.part_summary_table parts={@parts} />
        <.student_responses_section
          row_id={@row_id}
          parts={@parts}
          expanded_parts={@expanded_parts}
        />
      </div>
    <% end %>
    """
  end

  defp part_summary_table(assigns) do
    ~H"""
    <table class="mb-3 border-collapse text-sm text-Text-text-high">
      <caption class="sr-only">Part attempts summary</caption>
      <thead>
        <tr>
          <th scope="col" class="px-3 py-1 pl-0 text-left font-semibold">Part id</th>
          <th scope="col" class="px-3 py-1 text-left font-semibold">Attempt#</th>
          <th scope="col" class="px-3 py-1 text-left font-semibold">State</th>
          <th scope="col" class="px-3 py-1 text-left font-semibold">Score</th>
          <th scope="col" class="px-3 py-1 text-left font-semibold">Out of</th>
        </tr>
      </thead>
      <tbody>
        <%= for part <- @parts do %>
          <tr>
            <td class="px-3 py-1 pl-0">{part.part_id}</td>
            <td class="px-3 py-1">{part.attempt_number}</td>
            <td class="px-3 py-1">{part.lifecycle_state}</td>
            <td class="px-3 py-1">{part.score}</td>
            <td class="px-3 py-1">{part.out_of}</td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end

  defp student_responses_section(assigns) do
    ~H"""
    <div id={"responses-#{@row_id}"} class="mt-3">
      <div class="mb-2 flex items-center gap-3">
        <h3 class="m-0 text-base font-semibold text-Text-text-high">Student Responses</h3>
        <div :if={@parts != []} class="flex items-center gap-3">
          <Button.button
            id={"expand-all-#{@row_id}"}
            variant={:text}
            size={:sm}
            phx-click="expand_all_parts"
            phx-value-row={@row_id}
          >
            Expand all
          </Button.button>
          <Button.button
            id={"collapse-all-#{@row_id}"}
            variant={:text}
            size={:sm}
            phx-click="collapse_all_parts"
            phx-value-row={@row_id}
          >
            Collapse all
          </Button.button>
        </div>
      </div>
      <.part_response_card
        :for={part <- @parts}
        part_attempt={part}
        expanded_parts={@expanded_parts}
      />
    </div>
    """
  end

  defp part_response_card(assigns) do
    part = assigns.part_attempt

    assigns =
      assign(assigns,
        is_open: MapSet.member?(assigns.expanded_parts, part.id),
        has_response: has_any_content?(part.response),
        has_feedback: has_any_content?(part.feedback)
      )

    ~H"""
    <div class="part-response-card mb-2 rounded border border-Border-border-subtle bg-Surface-surface-primary">
      <button
        id={"part-toggle-#{@part_attempt.id}"}
        type="button"
        class="flex w-full cursor-pointer items-center gap-2 rounded-t border-0 bg-Background-bg-secondary p-2 text-left text-Text-text-high focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Border-border-focus"
        phx-click="toggle_part"
        phx-value-id={@part_attempt.id}
        aria-expanded={@is_open}
        aria-controls={"part-body-#{@part_attempt.id}"}
      >
        <Icons.chevron_down
          width="16"
          height="16"
          class={
            "fill-Icon-icon-active motion-safe:transition" <>
              if(@is_open, do: " rotate-180", else: "")
          }
        />
        <span class="mr-1 text-[0.7rem] uppercase tracking-wider text-Text-text-low">Part</span>
        <code>{@part_attempt.part_id}</code>
        <span class="ml-2 text-sm text-Text-text-low">
          (attempt {@part_attempt.attempt_number})
        </span>
      </button>
      <div id={"part-body-#{@part_attempt.id}"} class="p-2" hidden={not @is_open}>
        <div :if={@has_response}>
          <div class="mb-1 text-sm text-Text-text-low">Response</div>
          <.render_grouped_map data={@part_attempt.grouped_response} part_id={@part_attempt.id} />
        </div>
        <div :if={@has_feedback} class="mt-3">
          <div class="mb-1 text-sm text-Text-text-low">Feedback</div>
          <.render_grouped_map data={@part_attempt.grouped_feedback} part_id={@part_attempt.id} />
        </div>
        <p :if={not (@has_response or @has_feedback)} class="m-0 text-sm text-Text-text-low">
          No response data recorded for this part attempt.
        </p>
      </div>
    </div>
    """
  end

  defp render_grouped_map(assigns) do
    ~H"""
    <ul class="m-0 list-none p-0">
      <li :for={{key, value} <- @data} class="border-b border-Border-border-subtle py-1">
        <.grouped_map_row key={key} value={value} part_id={@part_id} />
      </li>
    </ul>
    """
  end

  defp grouped_map_row(%{value: value} = assigns) do
    cond do
      capi_variable?(value) -> capi_row(assigns)
      nested_group?(value) -> nested_group_row(assigns)
      true -> scalar_row(assigns)
    end
  end

  defp capi_row(assigns) do
    ~H"""
    <div class="grid grid-cols-[2fr_3fr] items-start gap-4">
      <span class="break-words font-medium text-Text-text-high">{to_string(@key)}</span>
      <div class={value_column_class(@value)}>
        <.render_capi_value
          value={@value["value"]}
          type={@value["type"]}
          allowed_values={@value["allowedValues"]}
          dom_id={safe_dom_id("capi-#{@part_id}", @value["id"] || @value["key"] || to_string(@key))}
        />
      </div>
    </div>
    """
  end

  defp nested_group_row(assigns) do
    ~H"""
    <details class="group/keygroup">
      <summary class="flex cursor-pointer list-none items-center gap-2 rounded focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Border-border-focus [&::-webkit-details-marker]:hidden">
        <Icons.chevron_down
          width="14"
          height="14"
          class="fill-Icon-icon-default motion-safe:transition group-open/keygroup:rotate-180"
        />
        <span class="font-medium text-Text-text-high">{to_string(@key)}</span>
      </summary>
      <div class="pl-4 pt-1">
        <.render_grouped_map data={@value} part_id={@part_id} />
      </div>
    </details>
    """
  end

  defp scalar_row(assigns) do
    ~H"""
    <div class="grid grid-cols-[2fr_3fr] items-start gap-4">
      <span class="break-words font-medium text-Text-text-high">{to_string(@key)}</span>
      <div class="min-w-0 overflow-x-auto whitespace-nowrap">
        <.render_value value={@value} />
      </div>
    </div>
    """
  end

  defp nested_group?(value) do
    is_list(value) and value != [] and Enum.all?(value, &match?({_, _}, &1))
  end

  defp render_value(assigns) do
    formatted = format_value_for_display(assigns.value)
    assigns = assign(assigns, :formatted, formatted)

    ~H"""
    <span class={@formatted.class}>{@formatted.text}</span>
    """
  end

  # Dispatches on the declared CapiVariable type code — mirrors AutoDetectInput.tsx.
  # NUMBER/ARRAY/BOOLEAN coerce stored strings back to their typed value before rendering.
  defp render_capi_value(%{type: @capi_type_enum, allowed_values: list} = assigns)
       when is_list(list) do
    options = Enum.map(list, fn v -> %{value: to_string(v), label: to_string(v)} end)

    assigns =
      assign(assigns,
        options: options,
        selected: to_string(assigns.value),
        dom_id: Map.get(assigns, :dom_id, "capi-enum-#{System.unique_integer([:positive])}")
      )

    ~H"""
    <SelectDropdown.render
      id={@dom_id}
      name="capi_enum"
      phx_change="capi_enum_readonly"
      options={@options}
      selected_value={@selected}
      push_on_select={false}
      readonly={true}
    />
    """
  end

  defp render_capi_value(%{type: t, value: v} = assigns)
       when t in [@capi_type_number, @capi_type_array, @capi_type_boolean] do
    coerced = coerce_for_type(v, t)
    assigns = assign(assigns, :coerced, coerced)

    ~H"""
    <.render_value value={@coerced} />
    """
  end

  # STRING/MATH_EXPR/ARRAY_POINT: stored value already matches what the renderer expects.
  defp render_capi_value(%{type: t} = assigns)
       when t in [@capi_type_string, @capi_type_math_expr, @capi_type_array_point] do
    ~H"""
    <.render_value value={@value} />
    """
  end

  # Fallback for nil/UNKNOWN(99)/ENUM-without-allowedValues/unrecognized types.
  defp render_capi_value(assigns) do
    ~H"""
    <.render_value value={@value} />
    """
  end

  def handle_event("toggle_row", %{"id" => unique_id}, socket) do
    # Only accept known row ids to cap expanded_rows MapSet growth.
    if Map.has_key?(socket.assigns.row_part_ids, unique_id) do
      expanded_rows =
        if MapSet.member?(socket.assigns.expanded_rows, unique_id) do
          MapSet.delete(socket.assigns.expanded_rows, unique_id)
        else
          MapSet.put(socket.assigns.expanded_rows, unique_id)
        end

      table_model =
        Map.update!(socket.assigns.table_model, :data, fn data ->
          Map.put(data, :expanded_rows, expanded_rows)
        end)

      {:noreply, assign(socket, table_model: table_model, expanded_rows: expanded_rows)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_row", _, socket), do: {:noreply, socket}

  def handle_event("toggle_part", %{"id" => id}, socket) do
    with id when is_integer(id) <- parse_part_id(id),
         true <- MapSet.member?(socket.assigns.valid_part_ids, id) do
      expanded_parts =
        if MapSet.member?(socket.assigns.expanded_parts, id) do
          MapSet.delete(socket.assigns.expanded_parts, id)
        else
          MapSet.put(socket.assigns.expanded_parts, id)
        end

      {:noreply,
       socket
       |> assign(expanded_parts: expanded_parts)
       |> update_table_model_expanded_parts(expanded_parts)}
    else
      _ -> {:noreply, socket}
    end
  end

  def handle_event("expand_all_parts", %{"row" => unique_id}, socket) do
    part_ids = Map.get(socket.assigns.row_part_ids, unique_id, [])

    expanded_parts =
      Enum.reduce(part_ids, socket.assigns.expanded_parts, &MapSet.put(&2, &1))

    {:noreply,
     socket
     |> assign(expanded_parts: expanded_parts)
     |> update_table_model_expanded_parts(expanded_parts)}
  end

  def handle_event("collapse_all_parts", %{"row" => unique_id}, socket) do
    part_ids = Map.get(socket.assigns.row_part_ids, unique_id, [])

    expanded_parts =
      Enum.reduce(part_ids, socket.assigns.expanded_parts, &MapSet.delete(&2, &1))

    {:noreply,
     socket
     |> assign(expanded_parts: expanded_parts)
     |> update_table_model_expanded_parts(expanded_parts)}
  end

  # Defensive no-op: push_on_select=false suppresses clicks, but the form's
  # phx-change still needs a handler to avoid crashing on stray events.
  def handle_event("capi_enum_readonly", _params, socket), do: {:noreply, socket}

  def handle_event("sort", %{"sort_by" => sort_by}, socket) do
    case sort_column_name(socket.assigns.table_model.column_specs, sort_by) do
      nil ->
        {:noreply, socket}

      column_name ->
        table_model =
          SortableTableModel.update_sort_params_and_sort(
            socket.assigns.table_model,
            column_name
          )

        {:noreply, assign(socket, table_model: table_model)}
    end
  end

  def handle_info({_, guid}, socket) do
    # Regroup only the changed attempt; others carry cached :grouped_* forward
    # to skip the tree walk on every PubSub tick.
    {changed, rest} =
      get_attempts(socket.assigns.attempt_guid) |> Enum.split_with(&(&1.attempt_guid == guid))

    refreshed_changed =
      changed
      |> Enum.map(&Map.put(&1, :updated, true))
      |> attach_unique_ids()
      |> precompute_grouped_responses()

    cached_by_guid = Map.new(socket.assigns.attempts, fn a -> {a.attempt_guid, a} end)

    carried_rest =
      Enum.map(rest, fn a ->
        case Map.get(cached_by_guid, a.attempt_guid) do
          nil ->
            # new row we haven't seen before — pay the grouping cost
            [processed] = precompute_grouped_responses([Map.put(a, :updated, false)])
            attach_unique_id(processed)

          cached ->
            Map.put(cached, :updated, false)
        end
      end)

    attempts =
      (refreshed_changed ++ carried_rest) |> Enum.sort_by(&{&1.resource_id, &1.attempt_number})

    %{valid_part_ids: valid_part_ids, row_part_ids: row_part_ids} = build_part_indexes(attempts)

    expanded_parts = MapSet.intersection(socket.assigns.expanded_parts, valid_part_ids)

    table_model =
      socket.assigns.table_model
      |> build_expandable_table_model(
        attempts,
        socket.assigns.expanded_rows,
        expanded_parts
      )
      |> SortableTableModel.sort()

    {:noreply,
     assign(socket,
       table_model: table_model,
       valid_part_ids: valid_part_ids,
       row_part_ids: row_part_ids,
       expanded_parts: expanded_parts,
       total_count: Enum.count(attempts),
       attempts: attempts
     )}
  end

  defp attach_unique_id(attempt), do: Map.put(attempt, :unique_id, "row_#{attempt.id}")

  defp get_attempts(resource_attempt_guid) do
    Repo.all(
      from(aa in ActivityAttempt,
        left_join: ra in ResourceAttempt,
        on: aa.resource_attempt_id == ra.id,
        left_join: r in Oli.Resources.Revision,
        on: aa.revision_id == r.id,
        where: ra.attempt_guid == ^resource_attempt_guid,
        select_merge: %{
          activity_title: r.title
        },
        preload: [:part_attempts],
        order_by: [:resource_id, :attempt_number]
      )
    )
  end

  # Returns nil on non-integer input so the handler bails before mixing strings into the MapSet.
  defp parse_part_id(id) when is_integer(id), do: id

  defp parse_part_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {i, ""} -> i
      _ -> nil
    end
  end

  defp parse_part_id(_), do: nil

  defp update_table_model_expanded_parts(socket, expanded_parts) do
    table_model =
      Map.update!(socket.assigns.table_model, :data, fn data ->
        Map.put(data, :expanded_parts, expanded_parts)
      end)

    assign(socket, table_model: table_model)
  end

  defp sort_column_name(column_specs, sort_by) do
    Enum.find_value(column_specs, fn %{name: name} ->
      case Atom.to_string(name) do
        ^sort_by -> name
        _ -> nil
      end
    end)
  end

  # ENUM opens a dropdown that needs overflow-visible to escape the row;
  # other values keep overflow-x-auto so long strings (e.g. customCss) scroll inline.
  defp value_column_class(%{"type" => @capi_type_enum}),
    do: "min-w-0 overflow-visible"

  defp value_column_class(_),
    do: "min-w-0 overflow-x-auto whitespace-nowrap"

  # Numeric hash — selector-safe; raw CAPI ids contain dots that break JS.toggle.
  defp safe_dom_id(prefix, raw) do
    "#{prefix}-#{:erlang.phash2(to_string(raw))}"
  end

  # Mirrors Inspector's unflatten: groups "Input 1.Correct" under a nested "Input 1".
  # On scalar vs nested-path collision, both are kept (scalar under "<key> (value)").
  # Returns pre-sorted {key, value} lists for nested groups.
  defp group_dotted_keys(data) when is_map(data) do
    data
    |> Enum.reduce(%{}, fn {k, v}, acc -> deep_put(acc, String.split(to_string(k), "."), v) end)
    |> sort_grouped()
  end

  defp group_dotted_keys(data), do: data

  # CAPI variable maps are left as-is so capi_variable?/1 still detects them.
  defp sort_grouped(data) when is_map(data) do
    if capi_variable?(data) do
      data
    else
      data
      |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
      |> Enum.map(fn {k, v} -> {k, sort_grouped(v)} end)
    end
  end

  defp sort_grouped(data), do: data

  defp deep_put(acc, [leaf], v) do
    case Map.get(acc, leaf) do
      existing when is_map(existing) and map_size(existing) > 0 ->
        Map.put(acc, "#{leaf} (value)", v)

      _ ->
        Map.put(acc, leaf, v)
    end
  end

  defp deep_put(acc, [head | rest], v) do
    case Map.get(acc, head) do
      nil ->
        Map.put(acc, head, deep_put(%{}, rest, v))

      existing when is_map(existing) ->
        Map.put(acc, head, deep_put(existing, rest, v))

      scalar ->
        acc
        |> Map.put("#{head} (value)", scalar)
        |> Map.put(head, deep_put(%{}, rest, v))
    end
  end

  # Detects the serialized CapiVariable shape the Janus runtime writes:
  # requires (key OR id) + path + type + value.
  defp capi_variable?(%{"key" => _, "path" => _, "type" => _, "value" => _}), do: true
  defp capi_variable?(%{"id" => _, "path" => _, "type" => _, "value" => _}), do: true
  defp capi_variable?(_), do: false

  # Mirrors parseCapiValue / coerceCapiValue (capi.ts) for the cases where a
  # stored value's shape differs from its declared type.
  defp coerce_for_type(v, @capi_type_boolean), do: coerce_capi_boolean(v)
  defp coerce_for_type(v, @capi_type_number), do: coerce_capi_number(v)
  defp coerce_for_type(v, @capi_type_array), do: coerce_capi_array(v)
  defp coerce_for_type(v, _), do: v

  defp coerce_capi_boolean(true), do: true
  defp coerce_capi_boolean(false), do: false
  defp coerce_capi_boolean("true"), do: true
  defp coerce_capi_boolean("false"), do: false
  defp coerce_capi_boolean(1), do: true
  defp coerce_capi_boolean(0), do: false
  defp coerce_capi_boolean(v), do: v

  defp coerce_capi_number(n) when is_number(n), do: n

  defp coerce_capi_number(s) when is_binary(s) do
    case Integer.parse(s) do
      {i, ""} ->
        i

      _ ->
        case Float.parse(s) do
          {f, ""} -> f
          _ -> s
        end
    end
  end

  defp coerce_capi_number(v), do: v

  defp coerce_capi_array(list) when is_list(list), do: list

  defp coerce_capi_array(s) when is_binary(s) do
    case Jason.decode(s) do
      {:ok, list} when is_list(list) -> list
      _ -> s
    end
  end

  defp coerce_capi_array(v), do: v

  defp has_any_content?(nil), do: false
  defp has_any_content?(map) when is_map(map), do: map_size(map) > 0
  defp has_any_content?(_), do: false

  defp format_value_for_display(true),
    do: %{class: "text-Text-text-accent-green", text: "✓ true"}

  defp format_value_for_display(false),
    do: %{class: "text-Text-text-danger", text: "✗ false"}

  defp format_value_for_display(nil),
    do: %{class: "italic text-Text-text-low", text: "nil"}

  defp format_value_for_display(v) when is_number(v),
    do: %{class: "font-mono", text: to_string(v)}

  # Renders empty string as explicit `""` to distinguish it from nil.
  defp format_value_for_display(""),
    do: %{class: "font-mono italic text-Text-text-low", text: ~s("")}

  defp format_value_for_display(v) when is_binary(v),
    do: %{class: "font-mono", text: v}

  defp format_value_for_display(v) when is_list(v),
    do: %{class: "font-mono", text: Jason.encode!(v)}

  defp format_value_for_display(v) when is_map(v),
    do: %{class: "font-mono", text: Jason.encode!(v)}

  defp format_value_for_display(other),
    do: %{class: "font-mono", text: inspect(other)}
end
