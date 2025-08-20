defmodule OliWeb.Projects.CreateProjectModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers

  alias OliWeb.Router.Helpers, as: Routes

  def render(assigns) do
    ~H"""
    <div
      class="modal fade fixed top-0 left-0 hidden w-full h-full outline-none overflow-x-hidden overflow-y-auto"
      id="exampleModal"
      tabindex="-1"
      aria-labelledby="exampleModalLabel"
      aria-hidden="true"
      phx-hook="ModalLaunch"
    >
      <div class="modal-dialog relative w-auto pointer-events-none">
        <div class="modal-content border-none shadow-lg relative flex flex-col w-full pointer-events-auto bg-white bg-clip-padding rounded-md outline-none text-current">
          <.form
            :let={f}
            for={@changeset}
            phx-change="validate_project"
            action={Routes.project_path(OliWeb.Endpoint, :create)}
          >
            <div class="modal-header flex flex-shrink-0 items-center justify-between p-4 border-b border-gray-200 rounded-t-md">
              <h5
                class="text-xl font-medium leading-normal text-gray-800 dark:text-[#eeebf5]"
                id="exampleModalLabel"
              >
                Create Project
              </h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close">
              </button>
            </div>
            <div class="modal-body relative p-4">
              <div class="form-label-group">
                {text_input(f, :title,
                  required: true,
                  class: "block min-w-full placeholder-[#9ca3af] dark:placeholder-[#eeebf5]/70",
                  placeholder: "e.g. Introduction to Psychology"
                )}
                <%= label f, :title, class: "block text-sm text-gray-500 dark:text-[#eeebf5]" do %>
                  This can be changed later
                <% end %>
                {error_tag(f, :title)}
              </div>
            </div>
            <div class="modal-footer flex flex-shrink-0 flex-wrap items-center justify-end p-4 border-t border-gray-200 rounded-b-md">
              {submit("Create", class: "btn btn-primary", phx_disable_with: "Creating Project...")}
            </div>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
