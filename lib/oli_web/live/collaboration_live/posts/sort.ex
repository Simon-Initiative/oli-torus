defmodule OliWeb.CollaborationLive.Posts.Sort do
  use Surface.Component

  prop sort, :struct, required: true

  def render(assigns) do
    ~F"""
    <div class="flex gap-2">
      <div class="flex text-xs">
        <button
          phx-click="sort"
          phx-value-sort_by="inserted_at"
          phx-value-sort_order={@sort.order}
          class={"#{if @sort.by == :inserted_at, do: "shadow-inner bg-delivery-primary-200 text-white", else: "shadow bg-white"} rounded-l-sm py-1 h-8 w-20"}
        >
          Date
        </button>
        <button
          phx-click="sort"
          phx-value-sort_by="replies_count"
          phx-value-sort_order={@sort.order}
          class={"#{if @sort.by == :replies_count, do: "shadow-inner bg-delivery-primary-200 text-white", else: "shadow bg-white"} rounded-r-sm py-1 h-8 w-20"}
        >
          Popularity
        </button>
      </div>

      <button
        type="button"
        phx-click="sort"
        phx-value-sort_by={@sort.by}
        phx-value-sort_order={if @sort.order == :desc, do: "asc", else: "desc"}
      >
        <i class={"fa fa-sort-amount-#{if @sort.order == :desc, do: "up", else: "down"}"} />
      </button>
    </div>
    """
  end
end
