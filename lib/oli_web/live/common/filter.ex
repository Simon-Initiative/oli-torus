defmodule OliWeb.Common.Filter do
  use Phoenix.Component

  alias OliWeb.Icons

  attr :change, :any, required: true
  attr :apply, :any, required: true
  attr :reset, :any, required: true
  attr :query, :string, default: ""
  attr :apply_icon, :boolean, default: false
  attr :show_reset, :boolean, default: true
  attr :placeholder, :string, default: "Search..."
  attr :debounce, :string, default: nil

  # `apply_icon: true` is a self-contained, single-consumer live-search variant (currently only
  # `OliWeb.Delivery.NewCourse.SelectSource`). It renders as a real `<form>` because
  # `phx-change` only fires on every keystroke (rather than only on blur/submit) when bound to a
  # `<form>` — the same convention already used elsewhere in this codebase for live-as-you-type
  # search (e.g. `hierarchy_picker.ex`), not when bound directly to a bare `<input>`.
  def render(%{apply_icon: true} = assigns) do
    ~H"""
    <form
      id="search_filter_form"
      phx-change={@change}
      phx-submit={@change}
      class="relative flex h-9 w-full items-center gap-3 rounded-[6px] border border-Specially-Tokens-Border-border-input bg-Specially-Tokens-Fill-fill-input py-1 pl-2.5 pr-2"
    >
      <Icons.search class="size-5 shrink-0 text-Icon-icon-default" />

      <input
        type="text"
        name="value"
        class="h-full min-w-0 flex-1 border-0 bg-transparent p-0 text-sm text-Text-text-high outline-none focus:outline-none focus:ring-0 focus:shadow-none placeholder:text-Text-text-low-alpha"
        placeholder={@placeholder}
        aria-label="Search"
        phx-debounce={@debounce}
        value={@query}
      />
      <button
        :if={@show_reset and @query not in [nil, ""]}
        id="reset_search"
        phx-click={@reset}
        type="button"
        aria-label="Clear search"
        class="flex size-6 shrink-0 items-center justify-center rounded-full text-Text-text-low-alpha hover:bg-Surface-surface-secondary-hover hover:text-Text-text-high"
      >
        <i class="fa-solid fa-xmark" />
      </button>
    </form>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="input-group search-input flex gap-2">
      <div class="relative flex flex-1 items-center">
        <input
          type="text"
          class="form-control h-full pr-6"
          placeholder={@placeholder}
          aria-label="Search"
          phx-change={@change}
          phx-blur={@change}
          phx-debounce={@debounce}
          value={@query}
        />
        <button
          :if={@show_reset}
          id="reset_search"
          phx-click={@reset}
          phx-type="button"
          class="absolute my-auto right-2 h-6 w-6 rounded-full hover:bg-delivery-primary-100 hover:text-white"
        >
          <i class="fa-solid fa-xmark" />
        </button>
      </div>
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
