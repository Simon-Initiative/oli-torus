defmodule OliWeb.ObjectivesLive.SelectExistingSubModal do
  use Surface.LiveComponent

  alias OliWeb.Common.TextSearch

  data filtered_sub_objectives, :list, default: []
  data query, :string, default: ""

  prop sub_objectives, :list, default: []
  prop parent_slug, :string, required: true
  prop add, :string, required: true

  def update(assigns, socket) do
    {:ok,
     assign(socket,
       id: assigns.id,
       parent_slug: assigns.parent_slug,
       add: assigns.add,
       sub_objectives: assigns.sub_objectives,
       filtered_sub_objectives: assigns.sub_objectives
     )}
  end

  def render(assigns) do
    ~F"""
      <div class="modal fade show" id={@id} style="display: block" tabindex="-1" role="dialog" aria-labelledby="show-existing-sub-modal" aria-hidden="true" phx-hook="ModalLaunch">
        <div class="modal-dialog" role="document">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Select existing Sub-Objective</h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
              <div class="container form-container">
                <TextSearch id="text-search" text={@query} event_target={@myself} />
                <div class="d-flex flex-column mt-3">
                  {#for sub_objective <- @filtered_sub_objectives}
                    <div class="my-2 d-flex">
                      <div class="p-1 mr-3 flex-grow-1 overflow-auto text-truncate">{sub_objective.title}</div>
                      <button
                        class="btn btn-outline-primary py-1"
                        phx-value-slug={sub_objective.slug}
                        phx-value-parent_slug={@parent_slug}
                        phx-click={@add}> Add
                      </button>
                    </div>
                  {/for}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    """
  end

  def handle_event("text_search_change", %{"value" => query}, socket) do
    query_str = String.downcase(query)

    filtered_sub_objectives =
      Enum.filter(socket.assigns.sub_objectives, fn sub ->
        String.contains?(String.downcase(sub.title), query_str)
      end)

    {:noreply,
     assign(socket,
       filtered_sub_objectives: filtered_sub_objectives,
       query: query
     )}
  end
end
