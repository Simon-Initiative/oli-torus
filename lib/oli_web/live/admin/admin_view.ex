defmodule OliWeb.Admin.AdminView do
  use OliWeb, :live_view

  alias Oli.{Accounts, Repo}
  alias OliWeb.Common.Properties.{Groups, Group}
  alias OliWeb.Common.Breadcrumb
  alias Oli.Accounts.{Author}
  alias OliWeb.Router.Helpers, as: Routes

  def mount(_, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)

    {:ok,
     assign(socket,
       author: author,
       breadcrumbs: breadcrumb()
     )}
  end

  attr :author, :any
  attr :breadcrumbs, :any
  attr :title, :string, default: "Admin"

  def render(assigns) do
    ~H"""
    <Groups.render>
      <div class="alert alert-warning mt-5" role="alert">
        <strong>Note:</strong>
        All administrative actions taken in the system are logged for auditing purposes.
      </div>
      <%= if Accounts.has_admin_role?(@author, :account_admin) do %>
        <Group.render label="Account Management" description="Access and manage all users and authors">
          <ul class="link-list">
            <li>
              <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersView)}>
                Manage Students and Instructor Accounts
              </a>
            </li>
            <li>
              <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsView)}>
                Manage Authoring Accounts
              </a>
            </li>
            <li>
              <a href={~p"/admin/institutions"}>
                Manage Institutions <%= badge(
                  assigns,
                  Oli.Institutions.count_pending_registrations() |> Oli.Utils.positive_or_nil()
                ) %>
              </a>
            </li>
            <li><a href={Routes.invite_path(OliWeb.Endpoint, :index)}>Invite New Authors</a></li>
            <li>
              <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.IndexView)}>
                Manage Communities
              </a>
            </li>
            <li>
              <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.RegistrationsView)}>
                Manage LTI 1.3 Registrations
              </a>
            </li>
          </ul>
        </Group.render>
      <% end %>
      <%= if Accounts.is_admin?(@author) do %>
        <Group.render label="Content Management" description="Access and manage created content">
          <ul class="link-list">
            <li>
              <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)}>
                Browse all Projects
              </a>
            </li>
            <li>
              <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Products.ProductsView)}>
                Browse all Products
              </a>
            </li>
            <li>
              <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.SectionsView)}>
                Browse all Course Sections
              </a>
            </li>
            <li>
              <a href={Routes.collab_spaces_index_path(OliWeb.Endpoint, :admin)}>
                Browse all Collaborative Spaces
              </a>
            </li>
            <li>
              <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.Ingest)}>Ingest Project</a>
            </li>
            <li><a href={Routes.ingest_path(OliWeb.Endpoint, :index)}>V2 Ingest Project</a></li>
            <li><a href={Routes.brand_path(OliWeb.Endpoint, :index)}>Manage Branding</a></li>
            <li>
              <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.PublisherLive.IndexView)}>
                Manage Publishers
              </a>
            </li>
          </ul>
        </Group.render>
      <% end %>
      <%= if Accounts.has_admin_role?(@author, :system_admin) do %>
        <Group.render
          label="System Management"
          description="Manage and support system level functionality"
        >
          <ul class="link-list">
            <li>
              <a href={Routes.activity_manage_path(OliWeb.Endpoint, :index)}>Manage Activities</a>
            </li>
            <li>
              <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.SystemMessageLive.IndexView)}>
                Manage System Message Banner
              </a>
            </li>

            <li>
              <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Features.FeaturesLive)}>
                Feature Flags and Logging
              </a>
            </li>
            <li>
              <a href={Routes.live_path(OliWeb.Endpoint, OliWeb.ApiKeys.ApiKeysLive)}>
                Manage Third-Party API Keys
              </a>
            </li>
            <li>
              <a href={~p"/admin/vr_user_agents"}>
                Manage VR User Agents
              </a>
            </li>
            <li>
              <a href={~p"/admin/xapi"}>
                XAPI Upload Pipeline Stats
              </a>
            </li>
            <li>
              <a href={Routes.live_dashboard_path(OliWeb.Endpoint, :home)} target="_blank">
                <span>View System Performance Dashboard</span>
                <i class="fas fa-external-link-alt self-center ml-1"></i>
              </a>
            </li>
          </ul>
        </Group.render>
      <% end %>
    </Groups.render>
    """
  end

  def badge(assigns, badge) do
    case badge do
      nil ->
        ""

      badge ->
        assigns = assign(assigns, badge: badge)

        ~H"""
        <span class="badge badge-pill badge-primary ml-2"><%= @badge %></span>
        """
    end
  end

  def breadcrumb(),
    do: [
      Breadcrumb.new(%{link: Routes.live_path(OliWeb.Endpoint, __MODULE__), full_title: "Admin"})
    ]
end
