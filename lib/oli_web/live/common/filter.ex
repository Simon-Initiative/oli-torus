defmodule OliWeb.Common.Filter do
  @moduledoc """
  Search filtering controls backed by the shared design-system Search Bar.

  The default variant keeps its explicit Search action. The `apply_icon`
  variant remains a live-search form for its existing consumer.
  """

  use Phoenix.Component

  alias OliWeb.Components.DesignTokens.Primitives.SearchBar

  attr :id, :string, default: "search_filter"
  attr :change, :any, required: true
  attr :apply, :any, required: true
  attr :reset, :any, required: true
  attr :query, :string, default: ""
  attr :apply_icon, :boolean, default: false
  attr :show_reset, :boolean, default: true
  attr :placeholder, :string, default: "Search..."
  attr :aria_label, :string, default: "Search"
  attr :debounce, :string, default: nil

  # `apply_icon: true` is a self-contained, single-consumer live-search variant (currently only
  # `OliWeb.Delivery.NewCourse.SelectSource`). It renders as a real `<form>` because
  # `phx-change` only fires on every keystroke (rather than only on blur/submit) when bound to a
  # `<form>` — the same convention already used elsewhere in this codebase for live-as-you-type
  # search (e.g. `hierarchy_picker.ex`), not when bound directly to a bare `<input>`.
  @doc """
  Renders either the default filter/search composition or its live-search variant.
  """
  def render(%{apply_icon: true} = assigns) do
    ~H"""
    <form
      id={@id <> "_form"}
      phx-change={@change}
      phx-submit={@change}
      class="w-full"
    >
      <SearchBar.search_bar
        id={@id <> "-input"}
        type="text"
        name="value"
        value={@query}
        placeholder={@placeholder}
        aria_label={@aria_label}
        class="w-full"
        on_clear={if @show_reset, do: @reset}
        clear_id="reset_search"
        phx-debounce={@debounce}
      />
    </form>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="input-group search-input flex gap-2">
      <SearchBar.search_bar
        id={@id <> "-input"}
        type="text"
        value={@query}
        placeholder={@placeholder}
        aria_label={@aria_label}
        class="min-w-0 flex-1"
        on_clear={if @show_reset, do: @reset}
        clear_id="reset_search"
        phx-change={@change}
        phx-blur={@change}
        phx-debounce={@debounce}
      />
      <button
        class="btn btn-outline-secondary border-none text-white bg-delivery-primary hover:bg-delivery-primary-400 active:bg-delivery-primary-600"
        phx-click={@apply}
        type="button"
      >
        Search
      </button>
    </div>
    """
  end
end
