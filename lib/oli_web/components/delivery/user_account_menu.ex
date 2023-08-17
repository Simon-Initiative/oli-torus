defmodule OliWeb.Components.Delivery.UserAccountMenu do
  use OliWeb, :html

  import OliWeb.Components.Delivery.Utils

  alias Oli.Accounts.{Author, SystemRole}
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.React

  attr(:ctx, SessionContext)
  attr(:section, Section)
  attr(:is_liveview, :boolean, default: false)

  def menu(assigns) do
    assigns = user_account_menu_assigns(assigns)

    # For some reason the react_live_component no longer works here (fails silently)
    # so for now, just render this component as if it were in a static page - is_liveview: false

    ~H"""
      <%= React.component(%SessionContext{@ctx | is_liveview: @is_liveview }, "Components.UserAccountMenu", %{
          user: @user,
          preview: @preview,
          routes: @routes,
          sectionSlug: @section_slug,
          selectedTimezone: @selected_timezone,
          timezones: @timezones,
        }, id: "menu") %>
    """
  end

  def user_account_menu_assigns(assigns) do
    assigns
    |> assign(
      :user,
      case assigns.ctx do
        %SessionContext{user: user_or_admin} when not is_nil(user_or_admin) ->
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
        signout: signout_path(assigns.ctx),
        projects: Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive),
        linkAccount: Routes.delivery_path(OliWeb.Endpoint, :link_account),
        editAccount: Routes.pow_registration_path(OliWeb.Endpoint, :edit),
        updateTimezone: Routes.static_page_path(OliWeb.Endpoint, :update_timezone),
        openAndFreeIndex: ~p"/sections"
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
      <div class="flex">
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

  defp signout_path(%SessionContext{user: user_or_admin}) do
    admin_role_id = SystemRole.role_id().admin

    case user_or_admin do
      %Author{system_role_id: ^admin_role_id} ->
        Routes.authoring_session_path(OliWeb.Endpoint, :signout, type: :author)

      _ ->
        Routes.session_path(OliWeb.Endpoint, :signout, type: :user)
    end
  end
end
