defmodule OliWeb.Objectives.SelectExistingSubModal do
  use Surface.Component

  prop id, :string, required: true
  prop parent_slug, :string, required: true
  prop sub_objectives, :list, required: true
  prop add, :event, required: true

  def render(assigns) do
    ~F"""
      <div class="modal fade show" id={@id} style="display: block" tabindex="-1" role="dialog" aria-labelledby="show-existing-sub-modal" aria-hidden="true" phx-hook="ModalLaunch">
        <div class="modal-dialog" role="document">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Select existing Sub-Objective</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close"><span aria-hidden="true">&times;</span></button>
            </div>
            <div class="modal-body">
              <div class="container form-container">
                <div class="d-flex flex-column">
                  {#for sub_objective <- @sub_objectives}
                    <div class="my-2 d-flex">
                      <div class="p-1 mr-3 flex-grow-1 overflow-auto text-truncate">{sub_objective.mapping.revision.title}</div>
                      <button
                        class="btn btn-outline-primary py-1"
                        type="submit"
                        phx-value-parent_slug={@parent_slug}
                        phx-value-slug={sub_objective.mapping.revision.slug}
                        :on-click={@add}> Add
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
end
