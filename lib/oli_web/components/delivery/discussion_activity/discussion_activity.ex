defmodule OliWeb.Components.Delivery.DiscussionActivity do
  use Surface.LiveComponent

  alias OliWeb.Common.PagedTable
  alias Phoenix.LiveView.JS

  prop limit, :number, default: 10
  prop filter, :string, required: true
  prop offset, :number, required: true
  prop count, :number, required: true
  prop collab_space_table_model, :struct, required: true
  prop discussion_table_model, :struct, required: true
  prop parent_component_id, :string, required: true
  prop section_slug, :string, required: true

  def render(assigns) do
    ~F"""
    <div class="p-10">
      <div class="bg-white dark:bg-gray-900 w-full">
        <h4 class="px-10 py-6 border-b border-b-gray-200 torus-h4">Discussion Activity</h4>

        <div class="flex items-end gap-2 px-10 py-6 border-b border-b-gray-200">
          <form phx-change="filter">
            <label class="cursor-pointer inline-flex flex-col gap-2">
              <small class="torus-small uppercase">Filter by</small>
              <select class="torus-select pr-32" name="filter">
                <option selected={@filter == :all} value="all">All</option>
                <option selected={@filter == :need_approval} value="need_approval">Posts that Need Approval</option>
                <option selected={@filter == :need_response} value="need_response">Posts Awaiting a Reply</option>
                <option selected={@filter == :by_discussion} value="by_discussion">By Discussion</option>
              </select>
            </label>
          </form>
        </div>

        <div id="discussion_activity_table">
          {#if @filter == :by_discussion}
            <PagedTable
              table_model={@collab_space_table_model}
              filter=""
              page_change={JS.push("paged_table_page_change", target: "##{@parent_component_id}")}
              total_count={@count}
              offset={@offset}
              limit={@limit}
              additional_table_class="border-0"
            />
          {#else}
            <PagedTable
              table_model={@discussion_table_model}
              filter=""
              page_change={JS.push("paged_table_page_change", target: "##{@parent_component_id}")}
              total_count={@count}
              offset={@offset}
              limit={@limit}
              additional_table_class="border-0"
            />
          {/if}
        </div>
      </div>
    </div>
    """
  end
end
