defmodule OliWeb.Components.Delivery.UserAccountMenu do
  use Phoenix.Component

  import Phoenix.HTML.Link

  import OliWeb.Components.Delivery.Utils

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections
  alias OliWeb.Common.SessionContext

  attr :current_user, User
  attr :context, SessionContext

  def menu(assigns) do
    ~H"""
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
            w-full
            whitespace-nowrap
            text-left
          "
          type="button"
          data-bs-toggle="dropdown"
          aria-expanded="false"
        >
          <div class="user-icon mr-4">
            <.user_icon current_user={@current_user} />
          </div>

          <div class="block">
            <div class="username">
              <%= user_name @current_user %>
            </div>
            <div class="role" style={"color: #{user_role_color(assigns[:section], @current_user)};"}>
              <%= user_role_text(assigns[:section], @current_user) %>
            </div>
          </div>
        </button>

        <ul
          class="
            dropdown-menu
            min-w-max
            absolute
            hidden
            bg-white
            text-base
            z-50
            float-right
            right-0
            p-2
            list-none
            text-left
            rounded-lg
            shadow-lg
            mt-1
            m-0
            bg-clip-padding
            border-none
          "
          aria-labelledby="accountDropdownMenu"
        >
          <%= if user_is_guest?(assigns) do %>
            <li>
              <%= link "Sign in / Create account", to: Routes.delivery_path(OliWeb.Endpoint, :signin, section: maybe_section_slug(assigns)), class: "dropdown-item btn" %>
            </li>

            <div id="create-account-popup"></div>
            <script>
              OLI.CreateAccountPopup(document.querySelector('#create-account-popup'), {sectionSlug: '<%= maybe_section_slug(assigns) %>'})
            </script>
          <% end %>
            <%= if (not user_role_is_student(assigns, @current_user)) or Sections.is_independent_instructor?(@current_user) do %>
              <li>
                <%= if account_linked?(@current_user) do %>
                  <h6 class="dropdown-item">Linked: <%= @current_user.author.email %></h6>
                  <a class="dropdown-item" href={Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)} target="_blank">Go to Course Author <i class="fas fa-external-link-alt float-right" style="margin-top: 2px"></i></a>
                  <a class="dropdown-item" href={Routes.delivery_path(OliWeb.Endpoint, :link_account)} target="_blank">Link a different account</a>
                <% else %>
                  <a class="dropdown-item" href={Routes.delivery_path(OliWeb.Endpoint, :link_account)} target="_blank">Link Existing Account</a>
                <% end %>
              </li>
            <% end %>

            <%= if user_is_independent_learner?(@current_user) do %>
              <li>
                <%= link "Edit Account", to: Routes.pow_registration_path(OliWeb.Endpoint, :edit), class: "dropdown-item btn" %>
                <div class="dropdown-item no-hover">
                  Dark Mode
                  <%= ReactPhoenix.ClientSide.react_component("Components.DarkModeSelector", %{showLabels: false}) %>
                </div>
              </li>
            <% end %>

            <li>
              <div class="dropdown-item no-hover">
                Timezone
                <br>
                <OliWeb.Common.SelectTimezone.render {assigns} />
              </div>
            </li>
            <hr class="dropdown-divider" />

            <%= if user_is_independent_learner?(@current_user) or Sections.is_independent_instructor?(@current_user) do %>
              <li>
                <%= link "My Courses", to: Routes.delivery_path(OliWeb.Endpoint, :open_and_free_index), class: "dropdown-item btn" %>
              </li>

              <hr class="dropdown-divider" />
            <% end %>

            <%= if user_is_guest?(assigns) do %>
            <li>
              <%= link "Leave course", to: Routes.session_path(OliWeb.Endpoint, :signout, type: :user), method: :delete, id: "signout-link", class: "dropdown-item btn" %>
            </li>
            <% else %>
            <li>
              <%= link "Sign out", to: Routes.session_path(OliWeb.Endpoint, :signout, type: :user), method: :delete, id: "signout-link", class: "dropdown-item btn" %>
            </li>
            <% end  %>
          </ul>
      </div>
    """
  end

  def preview_user(assigns) do
    ~H"""
      <div>
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
            <.user_icon />
          </div>
          <div class="block lg:inline-block lg:mt-0 text-grey-darkest mx-2">
            <div class="username">
              Preview
            </div>
          </div>
        </button>
      </div>
    """
  end
end
