defmodule OliWeb.Common.Filter do
  use Phoenix.Component

  alias OliWeb.Icons

  attr :change, :any, required: true
  attr :apply, :any, required: true
  attr :reset, :any, required: true
  attr :query, :string, default: ""
  attr :apply_icon, :boolean, default: false
  attr :search_label, :string, default: "Search"

  def render(assigns) do
    ~H"""
    <div class={
      if @apply_icon,
        do:
          "relative flex h-9 w-full items-center gap-3 rounded-[6px] border border-Specially-Tokens-Border-border-input bg-Specially-Tokens-Fill-fill-input p-1",
        else: "input-group search-input flex gap-2"
    }>
      <%= if @apply_icon do %>
        <button
          type="button"
          phx-click={@apply}
          class="inline-flex size-9 shrink-0 items-center justify-center rounded text-Icon-icon-default focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-Fill-Buttons-fill-primary"
          aria-label="Search"
        >
          <Icons.search class="size-5" />
        </button>
      <% end %>

      <div class={
        if @apply_icon,
          do: "relative flex min-w-0 flex-1 items-center",
          else: "relative flex flex-1 items-center"
      }>
        <input
          type="text"
          class={
            if @apply_icon,
              do:
                "h-full min-w-0 flex-1 border-0 bg-transparent p-0 text-sm text-Text-text-high outline-none placeholder:text-Text-text-low-alpha",
              else: "form-control h-full pr-6"
          }
          placeholder="Search..."
          aria-label={@search_label}
          phx-change={@change}
          phx-blur={@change}
          value={@query}
        />
        <button
          id="reset_search"
          phx-click={@reset}
          phx-type="button"
          class={
            if @apply_icon,
              do:
                "absolute right-0 my-auto size-6 rounded-full text-Text-text-low-alpha hover:bg-Surface-surface-secondary-hover hover:text-Text-text-high",
              else:
                "absolute my-auto right-2 h-6 w-6 rounded-full hover:bg-delivery-primary-100 hover:text-white"
          }
        >
          <i class="fa-solid fa-xmark" />
        </button>
      </div>
      <%= unless @apply_icon do %>
        <button
          class="btn btn-outline-secondary border-none text-white bg-delivery-primary hover:bg-delivery-primary-400 active:bg-delivery-primary-600"
          phx-click={@apply}
          type="button"
        >
          Search
        </button>
      <% end %>
    </div>
    """
  end
end
