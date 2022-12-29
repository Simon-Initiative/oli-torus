defmodule OliWeb.Delivery.Updates.ApplyUpdateModal do
  use Surface.Component

  import OliWeb.Common.FormatDateTime

  alias Oli.Publishing.Publications.Publication

  prop changes, :map, required: true
  prop current_publication, :struct, required: true
  prop id, :string, required: true
  prop newest_publication, :struct, required: true
  prop project_id, :integer, required: true
  prop updates, :map, required: true

  def render(assigns) do

    ~F"""
      <div class="modal fade show" id={@id} tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
        <div class="modal-dialog modal-lg" role="document">
          <div class="modal-content">

            <div class="modal-header">
              <h5 class="modal-title">Apply Update</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>

            <div class="modal-body">

              <h6 class="mb-3">Do you want to apply this update from
                <strong>v{version_number(@current_publication)}</strong> to <strong>v{version_number(@newest_publication)}</strong>?
              </h6>

              <div class="list-group-item flex-column align-items-start my-2">
                <div class="d-flex justify-content-between align-items-center">
                  <h5>{@newest_publication.project.title}</h5>
                  <small>Published {date(@newest_publication.published, precision: :relative)}</small>
                </div>
                <p class="mb-1">{@newest_publication.description}</p>
              </div>

              <hr class="bg-light">
              <h6 class="my-3">The following materials from this project will be updated to match the latest publication</h6>

              <ul>
                {#for {status, %{revision: revision}} <- Map.values(@changes)}
                  <li>
                    <span>{revision.title}</span>
                    <span class={"badge badge-secondary badge-#{status} mr-2"}>{status}</span>
                  </li>
                {/for}
              </ul>

              <!-- <div class="alert alert-warning my-2" role="alert">
                <b>This action cannot be undone.</b>
              </div> -->
            </div>

            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
              <button class="btn btn-warning" phx-click="apply_update" phx-key="enter">Apply Update</button>
            </div>

          </div>
        </div>
      </div>
    """
  end

  def version_number(%Publication{edition: edition, major: major, minor: minor}) do
    "#{edition}.#{major}.#{minor}"
  end
end
