defmodule OliWeb.Delivery.ManageSourceMaterials.ProjectCard do
  use Surface.Component

  prop id, :string, required: true
  prop title, :string, required: true
  prop tooltip, :string, required: true
  slot default

  def render(assigns) do
    ~F"""
      <div class="card my-4">
        <div class="card-header d-flex align-items-center" id={@id} phx-update="ignore">
          <h6 class="mb-0 mr-2">{@title}</h6>
          <i class="fa fa-info-circle" aria-hidden="true" data-toggle="tooltip" data-placement="right" title={@tooltip}></i>
        </div>
        <div class="card-body overflow-auto" style="max-height: 38rem">
          <#slot />
        </div>
      </div>
    """
  end
end
