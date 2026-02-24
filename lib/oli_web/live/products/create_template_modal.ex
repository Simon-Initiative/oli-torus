defmodule OliWeb.Products.CreateTemplateModal do
  use OliWeb, :html
  use Phoenix.HTML

  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers

  attr :id, :string, required: true
  attr :form, :any, required: true
  attr :submit_event, :string, default: "create"
  attr :validate_event, :string, default: "validate_create_template"

  def render(assigns) do
    ~H"""
    <div
      class="modal fade fixed top-0 left-0 hidden w-full h-full outline-none overflow-x-hidden overflow-y-auto"
      id={@id}
      tabindex="-1"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog relative w-auto pointer-events-none">
        <div class="modal-content border-none shadow-lg relative flex flex-col w-full pointer-events-auto bg-white bg-clip-padding rounded-md outline-none text-current">
          <.form :let={f} for={@form} phx-submit={@submit_event} phx-change={@validate_event}>
            <div class="modal-header flex flex-shrink-0 items-center justify-between p-4 border-b border-gray-200 rounded-t-md">
              <h5 class="text-xl font-medium leading-normal text-gray-800 dark:text-[#eeebf5]">
                Create Template
              </h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
              </button>
            </div>
            <div class="modal-body relative p-4">
              <div class="form-label-group">
                {text_input(f, :product_title,
                  required: true,
                  class: "block min-w-full placeholder-[#9ca3af] dark:placeholder-[#eeebf5]/70",
                  placeholder: "e.g. Introduction to Psychology Template"
                )}
                <%= label f, :product_title, class: "block text-sm text-gray-500 dark:text-[#eeebf5]" do %>
                  This can be changed later
                <% end %>
                {error_tag(f, :product_title)}
              </div>
            </div>
            <div class="modal-footer flex flex-shrink-0 flex-wrap items-center justify-end p-4 border-t border-gray-200 rounded-b-md">
              <button type="submit" class="btn btn-primary">Create</button>
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
