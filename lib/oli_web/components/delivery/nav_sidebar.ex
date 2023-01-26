defmodule OliWeb.Components.Delivery.NavSidebar do
  use Phoenix.Component

  import OliWeb.ViewHelpers, only: [brand_logo: 1]
  import OliWeb.Components.Delivery.Utils

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Components.Delivery.UserAccountMenu

  def nav_sidebar(assigns) do
    ~H"""
      <nav class="flex-col w-[200px] bg-white dark:bg-black relative shadow hidden lg:flex">
        <a class="block h-[40px] mt-2 mb-14 mx-auto" href={
          case assigns[:logo_link] do
            nil ->
              logo_link_path(assigns)
            logo_link ->
              logo_link
          end}>
          <%= brand_logo(Map.merge(assigns, %{class: "d-inline-block align-top"})) %>
        </a>

        <%= if assigns[:section] do %>
          <%= for {name, href, active} <- [{"Home", home_url(assigns), true}, {"Course Content", "#", false}, {"Discussion", "#", false}, {"Assignments", "#", false}, {"Exploration", "#", false}] do %>
            <a
              href={href}
              class={"
                block
                no-underline
                mx-6
                my-2
                hover:no-underline
                border-b
                border-transparent
                text-current
                hover:text-delivery-primary-400
                #{active && "font-bold border-b border-delivery-primary text-delivery-primary"}
              "}><%= name %></a>
          <% end %>
        <% end %>

        <div class="flex-1"></div>

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
                <div class="user-icon">
                  <%= user_icon(%{}) %>
                </div>
                <div class="block lg:inline-block lg:mt-0 text-grey-darkest mr-4">
                  <div class="username">
                    Preview
                  </div>
                </div>
              </button>
            </div>


          <% user_signed_in?(assigns) -> %>
            <UserAccountMenu.menu {assigns} />

          <% true -> %>

        <% end %>

        <hr class="border-t border-gray-300" />

        <button
          class="
            block
            no-underline
            m-4
            text-delivery-body-color
            font-bold
            hover:no-underline
            border-b
            border-transparent
            hover:text-delivery-primary
            active:text-delivery-primary-600
          "
          data-bs-toggle="modal"
          data-bs-target="#help-modal">
        Tech Support
        </button>
      </nav>
    """
  end

  defp home_url(assigns) do
    if assigns[:preview_mode] do
      Routes.page_delivery_path(OliWeb.Endpoint, :index_preview, assigns[:section_slug])
    else
      Routes.page_delivery_path(OliWeb.Endpoint, :index, assigns[:section_slug])
    end
  end
end
