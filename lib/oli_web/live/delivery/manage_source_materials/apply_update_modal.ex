defmodule OliWeb.Delivery.ManageSourceMaterials.ApplyUpdateModal do
  use OliWeb, :html

  import OliWeb.Common.FormatDateTime

  alias OliWeb.Common.Utils

  attr(:changes, :map, required: true)
  attr(:current_publication, :map, required: true)
  attr(:id, :string, required: true)
  attr(:newest_publication, :map, required: true)
  attr(:project_id, :integer, required: true)
  attr(:updates, :map, required: true)

  def render(assigns) do
    ~H"""
    <div
      class="modal fade show"
      id={@id}
      tabindex="-1"
      role="dialog"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog modal-lg" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">Apply Update - {@newest_publication.project.title}</h5>
            <button type="button" class="close" data-bs-dismiss="modal" aria-label="Close">
              <i class="fa-solid fa-xmark fa-xl"></i>
            </button>
          </div>

          <div class="modal-body pb-0">
            <h6 class="mb-3">
              Do you want to apply this update from
              <strong>
                {Utils.render_version(
                  @current_publication.edition,
                  @current_publication.major,
                  @current_publication.minor
                )}
              </strong>
              to <strong> <%= Utils.render_version(@newest_publication.edition, @newest_publication.major, @newest_publication.minor) %></strong>?
            </h6>

            <small>Latest publication description</small>

            <div class="alert alert-secondary" role="alert">
              <div class="d-flex justify-content-between align-items-center">
                <p class="mb-auto">{@newest_publication.description}</p>
                <small>
                  Published {date(@newest_publication.published, precision: :relative)}
                </small>
              </div>
            </div>

            <hr class="bg-light" />
            <h6 class="my-3">
              The following materials from this project will be updated to match the latest publication
            </h6>

            <ul class="my-3">
              <%= for {status, %{revision: revision}} <- Map.values(@changes) do %>
                <li>
                  <span class={"badge badge-secondary badge-#{status} mr-2"}>{status}</span>
                  <span>{revision.title}</span>
                </li>
              <% end %>
            </ul>

            <hr class="bg-light" />
          </div>

          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
            <button class="btn btn-warning ml-2" phx-click="apply_update" phx-key="enter">
              Apply Update
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
