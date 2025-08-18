defmodule OliWeb.Delivery.ManageSourceMaterials.ProjectCard do
  use OliWeb, :html

  attr(:id, :string, required: true)
  attr(:title, :string, required: true)
  attr(:tooltip, :string, required: true)
  slot(:inner_block, required: true)

  def render(assigns) do
    ~H"""
    <div class="card my-4">
      <div class="card-header d-flex align-items-center" id={@id} phx-update="ignore">
        <h6 class="mb-0 mr-2">{@title}</h6>
        <i
          class="fa fa-info-circle"
          aria-hidden="true"
          data-bs-toggle="tooltip"
          data-placement="right"
          title={@tooltip}
        >
        </i>
      </div>
      <div class="card-body overflow-auto" style="max-height: 38rem">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
