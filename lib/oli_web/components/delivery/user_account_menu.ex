defmodule OliWeb.Components.Delivery.UserAccountMenu do
  use Phoenix.Component

  import OliWeb.Components.Delivery.Utils

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections
  alias Oli.Accounts.User
  alias OliWeb.Common.SessionContext

  attr :current_user, User
  attr :context, SessionContext

  def menu(assigns) do
    assigns = user_account_menu_assigns(assigns)

    ~H"""
      <div id="menu" phx-update="ignore">
        <%= ReactPhoenix.ClientSide.react_component("Components.UserAccountMenu", %{
          user: @user,
          preview: @preview,
          routes: @routes,
          sectionSlug: @section_slug,
          browserTimezone: @browser_timezone,
          defaultTimezone: @default_timezone,
          timezones: Enum.map(@timezones, &Tuple.to_list/1),
        }) %>
      </div>
    """
  end

  def user_account_menu_assigns(assigns) do
    assigns
    |> assign(
      :user,
      case assigns do
        %{current_user: user_or_admin} when not is_nil(user_or_admin) ->
          %{
            picture: user_or_admin.picture,
            name: user_name(user_or_admin),
            role: user_role(assigns[:section], user_or_admin),
            roleLabel: user_role_text(assigns[:section], user_or_admin),
            roleColor: user_role_color(assigns[:section], user_or_admin),
            isGuest: user_is_guest?(assigns),
            isIndependentInstructor: Sections.is_independent_instructor?(user_or_admin),
            isIndependentLearner: user_is_independent_learner?(user_or_admin),
            linkedAuthorAccount: linked_author_account(user_or_admin),
            selectedTimezone: timezone_preference(user_or_admin)
          }

        _ ->
          nil
      end
    )
    |> assign(:preview, is_preview_mode?(assigns))
    |> assign(
      :routes,
      %{
        signin:
          Routes.delivery_path(OliWeb.Endpoint, :signin, section: maybe_section_slug(assigns)),
        signout: Routes.session_path(OliWeb.Endpoint, :signout, type: :user),
        projects: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive),
        linkAccount: Routes.delivery_path(OliWeb.Endpoint, :link_account),
        editAccount: Routes.pow_registration_path(OliWeb.Endpoint, :edit),
        updateTimezone: Routes.static_page_path(OliWeb.Endpoint, :update_timezone),
        openAndFreeIndex: Routes.delivery_path(OliWeb.Endpoint, :open_and_free_index)
      }
    )
    |> assign(
      :section_slug,
      maybe_section_slug(assigns)
    )
    |> OliWeb.Common.SelectTimezone.timezone_assigns()
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
