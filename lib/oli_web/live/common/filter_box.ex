defmodule OliWeb.Common.FilterBox do
  use OliWeb, :html

  # "The main filter/search"
  slot(:inner_block, required: true)
  slot(:card_body)
  # "Extra options that can be added next to search and/or sort"
  slot(:extra_opts)

  attr(:table_model, :map, required: true)
  attr(:card_header_text, :string, default: "Select Curriculum")

  attr(:card_body_text, :string,
    default: "Select a curriculum source to create your course section."
  )

  attr(:card_body_text_class, :string, default: "mt-1 mb-4")

  attr(:class, :string, default: "mb-3 w-full")
  attr(:header_class, :string, default: "pb-2")
  attr(:body_class, :string, default: nil)
  attr(:filter_opts_class, :string, default: "filter-opts flex flex-wrap items-center gap-2")
  attr(:inner_block_class, :string, default: "w-full")

  attr(:show_sort, :boolean, default: true)
  attr(:show_more_opts, :boolean, default: true)
  attr(:sort, :any, default: nil)

  def render(assigns) do
    ~H"""
    <div class={@class}>
      <h2 id="header_id" class={@header_class}>{@card_header_text}</h2>
      <div class={@body_class}>
        <%= if @card_body != [] do %>
          {render_slot(@card_body)}
        <% else %>
          <p class={@card_body_text_class}>{@card_body_text}</p>
        <% end %>
        <div class={@filter_opts_class}>
          <div class={@inner_block_class}>
            {render_slot(@inner_block)}
          </div>

          <%= if @show_sort do %>
            <div class="flex-1">
              <form id="sort" phx-change={@sort || "sort"} class="d-flex">
                <select name="sort_by" id="select_sort" class="custom-select mr-2 h-10">
                  <option value="" disabled selected>Sort by</option>
                  <%= for column_spec <- @table_model.column_specs do %>
                    <%= if column_spec.name != :action do %>
                      <option
                        value={column_spec.name}
                        selected={@table_model.sort_by_spec == column_spec}
                      >
                        {column_spec.label}
                      </option>
                    <% end %>
                  <% end %>
                </select>
                <div class="control d-flex align-items-center">
                  <div class="flex">
                    <label class="cursor-pointer">
                      <.input
                        type="checkbox"
                        name="sort_order"
                        class="hidden"
                        value={if @table_model.sort_order == :desc, do: "asc", else: "desc"}
                      />
                      <i class={"fa fa-sort-amount-#{if @table_model.sort_order == :desc, do: "up", else: "down"}"} />
                    </label>
                  </div>
                </div>
              </form>
            </div>
          <% end %>

          <%= if @show_more_opts do %>
            {render_slot(@extra_opts)}
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
