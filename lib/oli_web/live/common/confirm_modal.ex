defmodule OliWeb.Common.Confirm do
  use Phoenix.Component

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :ok, :any, required: true
  attr :cancel, :any, required: true
  attr :confirmation, :string, default: nil
  attr :confirmation_error, :string, default: nil
  attr :ok_label, :string, default: "Ok"
  attr :ok_variant, :string, default: "primary"
  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      class="modal fade show"
      tabindex="-1"
      role="dialog"
      aria-modal="true"
      aria-labelledby={"#{@id}-title"}
      aria-describedby={"#{@id}-body"}
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog modal-dialog-centered" role="document">
        <div class="modal-content">
          <div class="modal-header">
            <h5 id={"#{@id}-title"} class="modal-title">{@title}</h5>
          </div>
          <div id={"#{@id}-body"} class="modal-body">
            {render_slot(@inner_block)}
            <%= if @confirmation do %>
              <label for={"#{@id}-confirmation"} class="form-label mt-3">
                Type <code>{@confirmation}</code> to continue.
              </label>
              <p
                :if={@confirmation_error}
                id={"#{@id}-confirmation-error"}
                class="text-danger"
                role="alert"
              >
                {@confirmation_error}
              </p>
              <form id={"#{@id}-form"} phx-submit={@ok}>
                <input
                  id={"#{@id}-confirmation"}
                  name="confirmation"
                  type="text"
                  class="form-control"
                  autocomplete="off"
                  required
                  autofocus
                  aria-invalid={if @confirmation_error, do: "true", else: "false"}
                  aria-describedby={
                    if @confirmation_error, do: "#{@id}-confirmation-error", else: nil
                  }
                />
              </form>
            <% end %>
          </div>
          <div class="modal-footer">
            <button
              type="button"
              class="btn btn-secondary"
              data-bs-dismiss="modal"
              phx-click={@cancel}
            >
              Cancel
            </button>
            <button
              type={if @confirmation, do: "submit", else: "button"}
              form={if @confirmation, do: "#{@id}-form", else: nil}
              class={"btn btn-#{@ok_variant}"}
              data-bs-dismiss={if @confirmation, do: nil, else: "modal"}
              phx-click={if @confirmation, do: nil, else: @ok}
            >
              {@ok_label}
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
