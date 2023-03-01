defmodule OliWeb.Components.Delivery.NavSidebar do
  use Phoenix.Component

  import OliWeb.Components.Delivery.Utils
  import Oli.Utils, only: [value_or: 2]
  import Oli.Branding

  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Branding.Brand
  alias Oli.Delivery.Sections
  alias Oli.Accounts

  slot :inner_block, required: true

  def main_with_nav(assigns) do
    ~H"""
      <main role="main" class="h-screen flex flex-col relative lg:flex-row">
        <.navbar {assigns} path_info={@conn.path_info} />

        <div class="flex-1 flex flex-col lg:pl-[200px]">

          <%= render_slot(@inner_block) %>

        </div>
      </main>
    """
  end

  attr :path_info, :list

  def navbar(%{path_info: path_info} = assigns) do
    assigns =
      assigns
      |> assign(
        :logo,
        logo_details(assigns)
      )
      |> assign(
        :links,
        if is_preview_mode?(assigns) do
          [
            %{
              name: "Home",
              href: "#",
              active: is_active(path_info, :overview)
            },
            %{name: "Course Content", href: "#", active: is_active(path_info, "")},
            %{name: "Discussion", href: "#", active: is_active(path_info, "")},
            %{name: "Assignments", href: "#", active: is_active(path_info, "")},
            %{
              name: "Exploration",
              href: "#",
              active: is_active(path_info, :exploration)
            }
          ]
        else
          [
            %{
              name: "Home",
              href: home_url(assigns),
              active: is_active(path_info, :overview)
            },
            %{name: "Course Content", href: "#", active: is_active(path_info, "")},
            %{name: "Discussion", href: "#", active: is_active(path_info, "")},
            %{name: "Assignments", href: "#", active: is_active(path_info, "")},
            %{
              name: "Exploration",
              href: exploration_url(assigns),
              active: is_active(path_info, :exploration)
            }
          ]
        end
      )
      |> assign(
        :user,
        case assigns do
          %{current_user: current_user} when not is_nil(current_user) ->
            %{
              picture: current_user.picture,
              name: user_name(current_user),
              role: user_role(assigns[:section], current_user),
              roleLabel: user_role_text(assigns[:section], current_user),
              roleColor: user_role_color(assigns[:section], current_user),
              isGuest: user_is_guest?(assigns),
              isIndependentInstructor: Sections.is_independent_instructor?(current_user),
              isIndependentLearner: user_is_independent_learner?(current_user),
              linkedAuthorAccount:
                if account_linked?(current_user) do
                  %{
                    email: current_user.author.email
                  }
                else
                  nil
                end,
              selectedTimezone: Accounts.get_user_preference(current_user, :timezone)
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

    ~H"""
      <%= ReactPhoenix.ClientSide.react_component("Components.Navbar", %{
        logo: @logo,
        links: @links,
        user: @user,
        preview: @preview,
        routes: @routes,
        sectionSlug: @section_slug,
        browserTimezone: @browser_timezone,
        defaultTimezone: @default_timezone,
        timezones: Enum.map(@timezones, &Tuple.to_list/1),
      }) %>
    """
  end

  defp logo_details(assigns) do
    %{
      href:
        case assigns[:logo_link] do
          nil ->
            logo_link_path(assigns)

          logo_link ->
            logo_link
        end,
      src:
        case assigns do
          %{brand: %Brand{logo: logo, logo_dark: logo_dark}} ->
            %{light: logo, dark: value_or(logo_dark, logo)}

          _ ->
            %{
              light: brand_logo_url(assigns[:section]),
              dark: brand_logo_url_dark(assigns[:section])
            }
        end
    }
  end

  defp is_active(["sections", _, "overview"], :overview), do: true
  defp is_active(["sections", _, "exploration"], :exploration), do: true
  defp is_active(["sections", _, "preview", "overview"], :overview), do: true
  defp is_active(["sections", _, "preview", "exploration"], :exploration), do: true
  defp is_active(_, _), do: false

  defp home_url(assigns) do
    if assigns[:preview_mode] do
      Routes.live_path(
        OliWeb.Endpoint,
        OliWeb.Delivery.InstructorDashboard.ContentLive,
        assigns[:section_slug]
      )
    else
      Routes.page_delivery_path(OliWeb.Endpoint, :index, assigns[:section_slug])
    end
  end

  defp exploration_url(assigns) do
    if assigns[:preview_mode] do
      Routes.page_delivery_path(OliWeb.Endpoint, :exploration_preview, assigns[:section_slug])
    else
      Routes.page_delivery_path(OliWeb.Endpoint, :exploration, assigns[:section_slug])
    end
  end
end
