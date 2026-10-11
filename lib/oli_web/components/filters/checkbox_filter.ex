defmodule OliWeb.Components.Filters.CheckboxFilter do
  @moduledoc """
  A dropdown filter of checkboxes, with an optional search box, composed from
  `OliWeb.Components.Filters.DropdownFilter`. The applied values belong to the parent
  (`selected_ids`). Checking changes a draft that the panel renders; searching only hides options.
  Apply sends the form's checked options to the parent as `{:filter_applied, on_apply, ids}`.
  Cancel, Escape and a click outside discard the draft; Apply, Cancel and Escape return focus to
  the trigger.
  """

  use OliWeb, :live_component

  alias OliWeb.Components.Filters.DropdownFilter
  alias Phoenix.LiveView.JS

  def mount(socket) do
    {:ok, assign(socket, open: false, draft: [], query: "", searchable: false)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="relative inline-block"
      phx-click-away={@open && JS.push("cancel", target: @myself)}
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
          phx-submit={JS.push("apply", target: @myself) |> JS.focus(to: "##{@id}-trigger")}
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
            id={@id}
            legend={@label}
            options={@options}
            checked={@draft}
            visible={visible_ids(@options, @query)}
          />
          <DropdownFilter.actions id={@id} cancel={close_and_focus_trigger(@id, @myself)} />
        </.form>
      </DropdownFilter.panel>
    </div>
    """
  end

  def handle_event("toggle", _params, %{assigns: %{open: true}} = socket),
    do: {:noreply, close(socket)}

  def handle_event("toggle", _params, socket),
    do: {:noreply, assign(socket, open: true, draft: socket.assigns.selected_ids, query: "")}

  # A debounced search change can arrive after a reconnect has restored the draft, carrying no
  # checked boxes; only a checkbox change sets the draft.
  def handle_event("change", %{"_target" => ["query" | _]} = params, socket) do
    {:noreply, assign(socket, query: search_query(params, socket.assigns.query))}
  end

  def handle_event("change", params, socket) do
    {:noreply,
     assign(socket,
       draft: checked_ids(params, socket.assigns.options),
       query: search_query(params, socket.assigns.query)
     )}
  end

  # After a reconnect, LiveView replays each form here; only a form rendered open says so. A late
  # `change` never reopens: Escape's blur can flush a debounced search after the close.
  def handle_event("recover", params, socket) do
    {:noreply,
     assign(socket,
       open: params["open"] == "true",
       draft: checked_ids(params, socket.assigns.options),
       query: search_query(params, "")
     )}
  end

  def handle_event("apply", params, socket) do
    send(
      self(),
      {:filter_applied, socket.assigns.on_apply, checked_ids(params, socket.assigns.options)}
    )

    {:noreply, close(socket)}
  end

  def handle_event("cancel", _params, socket), do: {:noreply, close(socket)}

  defp close(socket), do: assign(socket, open: false, draft: [], query: "")

  defp close_and_focus_trigger(id, target),
    do: JS.push("cancel", target: target) |> JS.focus(to: "##{id}-trigger")

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
