defmodule OliWeb.Components.Delivery.NavSidebar do
  use Phoenix.Component

  import OliWeb.ViewHelpers, only: [brand_logo: 1]
  import OliWeb.Components.Delivery.Utils

  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Components.Delivery.UserAccountMenu

  slot :inner_block, required: true

  def main_with_nav(assigns) do
    ~H"""
      <main role="main" class="flex-1 flex flex-col lg:flex-row">
        <.navbar {assigns} />

        <div class="flex-1 flex flex-col">

          <%= render_slot(@inner_block) %>

        </div>
      </main>
    """
  end

  @spec navbar(any) :: Phoenix.LiveView.Rendered.t()
  def navbar(assigns) do
    ~H"""
      <nav class="flex flex-col w-full lg:w-[200px] py-2 bg-white dark:bg-black relative shadow-lg lg:flex">
        <div class="w-full">
          <a class="block w-[200px] lg:mb-14 mx-auto" href={
          case assigns[:logo_link] do
            nil ->
              logo_link_path(assigns)
            logo_link ->
              logo_link
          end}>
          <%= brand_logo(Map.merge(assigns, %{class: "h-[40px] inline-block align-top"})) %>
          </a>

          <button class="
              navbar-toggler
              lg:hidden
              text-gray-500
              border-0
              absolute right-2 top-2
              hover:shadow-none hover:no-underline
              py-2
              px-2.5
              bg-transparent
              focus:outline-none focus:ring-0 focus:shadow-none focus:no-underline
            " type="button" data-bs-toggle="collapse" data-bs-target="#navbarSupportedContent" aria-controls="navbarSupportedContent" aria-expanded="false" aria-label="Toggle navigation">
            <svg aria-hidden="true" focusable="false" data-prefix="fas" data-icon="bars"
              class="w-6" role="img" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512">
              <path fill="currentColor"
                d="M16 132h416c8.837 0 16-7.163 16-16V76c0-8.837-7.163-16-16-16H16C7.163 60 0 67.163 0 76v40c0 8.837 7.163 16 16 16zm0 160h416c8.837 0 16-7.163 16-16v-40c0-8.837-7.163-16-16-16H16c-8.837 0-16 7.163-16 16v40c0 8.837 7.163 16 16 16zm0 160h416c8.837 0 16-7.163 16-16v-40c0-8.837-7.163-16-16-16H16c-8.837 0-16 7.163-16 16v40c0 8.837 7.163 16 16 16z">
              </path>
            </svg>
          </button>
        </div>

        <div class="collapse lg:!flex navbar-collapse flex-grow flex flex-col " id="navbarSupportedContent">

          <div class="flex-1 items-center lg:items-start">
            <%= if assigns[:section] do %>
              <%= for {name, href, active} <- [{"Home", home_url(assigns), true}, {"Course Content", "#", false}, {"Discussion", "#", false}, {"Assignments", "#", false}, {"Exploration", "#", false}] do %>
                <.nav_link name={name} href={href} active={active} />
              <% end %>
            <% end %>

            <%= if is_preview_mode?(assigns) do %>
              <%= for {name, href, active} <- [{"Home", "#", true}, {"Course Content", "#", false}, {"Discussion", "#", false}, {"Assignments", "#", false}, {"Exploration", "#", false}] do %>
                <.nav_link name={name} href={href} active={active} />
              <% end %>
            <% end %>
          </div>

          <%= cond do %>
          <% assigns[:hide_user] == true -> %>

          <% is_preview_mode?(assigns) -> %>
            <UserAccountMenu.preview_user {assigns} />

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
        </div>
      </nav>
    """
  end

  attr :name, :string, required: true
  attr :href, :string, required: true
  attr :active, :boolean, required: true

  defp nav_link(assigns) do
    ~H"""
      <a
        href={@href}
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
          #{@active && "font-bold border-b border-delivery-primary text-delivery-primary"}
        "}><%= @name %></a>
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
