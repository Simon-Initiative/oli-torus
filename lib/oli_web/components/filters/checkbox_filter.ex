defmodule OliWeb.Components.Filters.CheckboxFilter do
  @moduledoc """
  A dropdown filter of checkboxes, with an optional search box, composed from
  `OliWeb.Components.Filters.DropdownFilter`. The applied values belong to the parent
  (`selected_ids`) and the boxes show them. Each checkbox change sends the form's checked options
  to the parent as `{:filter_applied, on_apply, ids}`; searching only hides options. With
  `max_selected`, a change that would check more options sends
  `{:filter_limit_reached, on_apply, max_selected}` instead and every box is rendered again, so
  the browser drops the refused check. Escape, a click outside and the trigger close the panel;
  Escape returns focus to the trigger.
  """

  use OliWeb, :live_component

  alias OliWeb.Components.Filters.DropdownFilter
  alias Phoenix.LiveView.JS

  def mount(socket) do
    {:ok,
     assign(socket, open: false, query: "", searchable: false, max_selected: nil, refusals: 0)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="relative inline-block"
      phx-click-away={@open && JS.push("close", target: @myself)}
      phx-window-keydown={@open && close_and_focus_trigger(@id, @myself)}
      phx-key="Escape"
    >
      <DropdownFilter.trigger
        id={@id}
        label={@label}
        open={@open}
        selected_count={length(@selected_ids)}
        phx-click="toggle"
        phx-target={@myself}
      />
      <DropdownFilter.panel id={@id} open={@open}>
        <.form
          for={%{}}
          id={"#{@id}-form"}
          phx-change="change"
          phx-submit="search"
          phx-auto-recover="recover"
          phx-target={@myself}
        >
          <input :if={@open} type="hidden" name="open" value="true" />
          <DropdownFilter.search
            :if={@searchable}
            id={@id}
            label={"Search #{String.downcase(@label)}"}
            value={@query}
          />
          <DropdownFilter.checkbox_options
            :if={@open}
            id={@id}
            legend={@label}
            options={@options}
            checked={@selected_ids}
            visible={visible_ids(@options, @query)}
            revision={@refusals}
          />
        </.form>
      </DropdownFilter.panel>
    </div>
    """
  end

  def handle_event("toggle", _params, %{assigns: %{open: true}} = socket),
    do: {:noreply, close(socket)}

  def handle_event("toggle", _params, socket),
    do: {:noreply, assign(socket, open: true, query: "")}

  # A debounced search change can arrive after the panel closed; only a checkbox change applies.
  def handle_event("change", %{"_target" => ["query" | _]} = params, socket) do
    {:noreply, assign(socket, query: search_query(params, socket.assigns.query))}
  end

  def handle_event("change", params, socket) do
    %{options: options, on_apply: on_apply, max_selected: max} = socket.assigns
    ids = checked_ids(params, options)
    socket = assign(socket, query: search_query(params, socket.assigns.query))

    case is_integer(max) and length(ids) > max do
      true ->
        send(self(), {:filter_limit_reached, on_apply, max})
        {:noreply, update(socket, :refusals, &(&1 + 1))}

      false ->
        send(self(), {:filter_applied, on_apply, ids})
        {:noreply, socket}
    end
  end

  def handle_event("search", params, socket),
    do: {:noreply, assign(socket, query: search_query(params, socket.assigns.query))}

  # After a reconnect, LiveView replays each form here; only a form rendered open says so. The
  # boxes keep showing the applied values: a check the server never received is not applied.
  def handle_event("recover", params, socket) do
    {:noreply, assign(socket, open: params["open"] == "true", query: search_query(params, ""))}
  end

  def handle_event("close", _params, socket), do: {:noreply, close(socket)}

  defp close(socket), do: assign(socket, open: false)

  defp close_and_focus_trigger(id, target),
    do: JS.push("close", target: target) |> JS.focus(to: "##{id}-trigger")

  # Form values are strings; only the ids of real options go back, as the options carry them.
  defp checked_ids(params, options) do
    checked =
      params
      |> Map.get("selected", [])
      |> List.wrap()
      |> Enum.filter(&is_binary/1)
      |> MapSet.new()

    options
    |> Enum.filter(&MapSet.member?(checked, to_string(&1.id)))
    |> Enum.map(& &1.id)
  end

  defp search_query(%{"query" => query}, _current) when is_binary(query), do: query
  defp search_query(%{"query" => _not_text}, _current), do: ""
  defp search_query(_params, current), do: current

  defp visible_ids(options, query) do
    case String.trim(query) do
      "" ->
        nil

      term ->
        term = String.downcase(term)

        options
        |> Enum.filter(&String.contains?(String.downcase(&1.label), term))
        |> Enum.map(& &1.id)
    end
  end
end
