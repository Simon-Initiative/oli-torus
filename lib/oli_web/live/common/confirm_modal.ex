defmodule OliWeb.Common.Confirm do
  use Surface.LiveComponent

  prop title, :string, required: true
  prop ok, :event, required: true
  prop cancel, :event, required: true
  slot default

  def render(assigns) do
    ~F"""
    <div id={@id} class={"modal fade show"} tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{@title}</h5>
          </div>
          <div class="modal-body">
            <#slot />
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal" :on-click={@cancel}>Cancel</button>
            <button type="button" class="btn btn-primary" data-bs-dismiss="modal" :on-click={@ok}>Ok</button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
