defmodule OliWeb.Delivery.ManageSourceMaterials.ProjectInfo do
  use Surface.Component

  alias OliWeb.Common.Utils

  prop project, :struct, required: true
  prop current_publication, :struct, required: true
  prop newest_publication, :struct, required: true
  prop updates, :map, required: true
  prop updates_in_progress, :map, required: true

  def render(assigns) do
    ~F"""

      <div class="card-title">
        <div class="d-flex align-items-center">
          <h5 class="mb-0">{@project.title}</h5>
          <span class="badge badge-info ml-2">{Utils.render_version(@current_publication.edition, @current_publication.major, @current_publication.minor)}</span>
        </div>
      </div>

      <p class="card-text">{@project.description}</p>

      {#unless @newest_publication == nil}
        <hr class="bg-light">
        <div class="d-flex justify-content-between align-items-center mt-3">
          <div class="d-flex">
            <h6 class="mb-0">An update is available for this section</h6>
            <span class="badge badge-success ml-2">{Utils.render_version(@newest_publication.edition, @newest_publication.major, @newest_publication.minor)}</span>
          </div>
          {#if Map.has_key?(@updates_in_progress, @newest_publication.id)}
            <button type="button" class="btn btn-sm btn-primary" disabled>Update in progress...</button>
          {#else}
            <button type="button" class="btn btn-sm btn-primary"
              phx-click="show_apply_update_modal"
              phx-value-project-id={@newest_publication.project_id}
              phx-value-publication-id={@newest_publication.id}>View Update</button>
          {/if}
        </div>
      {/unless}

    """
  end
end
