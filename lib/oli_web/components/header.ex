defmodule OliWeb.Components.Header do
  use Phoenix.Component

  import Phoenix.HTML.Link
  import OliWeb.ViewHelpers, only: [brand_logo: 1]

  import OliWeb.Components.Delivery.Utils

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Components.Delivery.UserAccountMenu
  alias OliWeb.Components.Delivery.Buttons
  alias OliWeb.Breadcrumb.BreadcrumbTrailLive

  def header(assigns) do
    ~H"""
    <nav class="navbar py-1">
      <div class="container mx-auto flex flex-row">

        <a class="navbar-brand torus-logo my-1 mr-auto" href={case assigns[:logo_link] do
          nil ->
            logo_link_path(assigns)
          logo_link ->
            logo_link
          end}>
          <%= brand_logo(Map.merge(assigns, %{class: "d-inline-block align-top mr-2"})) %>
        </a>

        <%= if not is_preview_mode?(assigns) do %>
          <div class="nav-item my-2 my-lg-0 mr-2">
            <Buttons.help_button />
          </div>
        <% end %>

        <%= cond do %>
          <% assigns[:hide_user] == true -> %>

          <% is_preview_mode?(assigns) -> %>
            <div class="dropdown relative">
              <button
                class="
                  dropdown-toggle
                  px-6
                  py-2.5
                  font-medium
                  text-sm
                  leading-tight
                  transition
                  duration-150
                  ease-in-out
                  flex
                  items-center
                  whitespace-nowrap
                "
                type="button"
                data-bs-toggle="dropdown"
                aria-expanded="false"
              >
                <div class="block lg:inline-block lg:mt-0 text-grey-darkest mr-4">
                  <div class="username">
                    Preview
                  </div>
                </div>
                <div class="user-icon">
                  <%= user_icon(%{}) %>
                </div>
              </button>
            </div>

          <% user_signed_in?(assigns) -> %>
            <div class="max-w-[400px]">
              <UserAccountMenu.menu {assigns} />
            </div>

          <% true -> %>
            <%= link "Learner/Educator Sign In", to: Routes.pow_session_path(OliWeb.Endpoint, :new), class: "btn btn-primary btn-sm my-2 flex items-center" %>

        <% end %>
      </div>
    </nav>
    <.delivery_breadcrumb breadcrumbs={assigns[:breadcrumbs]} socket_or_conn={socket_or_conn(assigns)} />
    """
  end

  attr :breadcrumbs, :list, required: true
  attr :socket_or_conn, :any, required: true

  def delivery_breadcrumb(assigns) do
    ~H"""
    <%= if delivery_breadcrumbs?(assigns) do %>
      <div class="container mx-auto my-2">
        <nav class="breadcrumb-bar d-flex align-items-center mt-3 mb-1">
          <div class="flex-1">
            <%= live_render(@socket_or_conn, BreadcrumbTrailLive, session: %{"breadcrumbs" => @breadcrumbs}) %>
          </div>
        </nav>
      </div>
    <% end %>
    """
  end
end
