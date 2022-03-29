defmodule OliWeb.Admin.AdminView do
  use Surface.LiveView, layout: {OliWeb.LayoutView, "live.html"}
  alias Oli.Repo
  alias OliWeb.Common.Properties.{Groups, Group}
  alias OliWeb.Common.Breadcrumb
  alias Oli.Accounts.{Author}
  alias OliWeb.Router.Helpers, as: Routes

  prop author, :any
  data breadcrumbs, :any
  data title, :string, default: "Admin"

  def mount(_, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)

    {:ok,
     assign(socket,
       author: author,
       breadcrumbs: breadcrumb()
     )}
  end

  def render(assigns) do
    ~F"""
    <Groups>
      <div class="alert alert-warning mt-5" role="alert">
        <strong>Note:</strong> All administrative actions taken in the system are logged for auditing purposes.
      </div>
      <Group label="Account Management" description="Access and manage all users and authors">
        <ul class="link-list">
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.UsersView)}>Manage Students and Instructor Accounts</a></li>
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsView)}>Manage Authoring Accounts</a></li>
          <li><a href={Routes.institution_path(OliWeb.Endpoint, :index)}>Manage Institutions {badge(assigns, (Oli.Institutions.count_pending_registrations() |> Oli.Utils.positive_or_nil))}</a></li>
          <li><a href={Routes.invite_path(OliWeb.Endpoint, :index)}>Invite New Authors</a></li>
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.CommunityLive.IndexView)}>Manage Communities</a></li>
        </ul>
      </Group>
      <Group label="Content Management" description="Access and manage created content">
        <ul class="link-list">
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Projects.ProjectsLive)}>Browse all Projects</a></li>
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Products.ProductsView)}>Browse all Products</a></li>
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Sections.SectionsView)}>Browse all Course Sections</a></li>
          <li><a href={Routes.admin_open_and_free_path(OliWeb.Endpoint, :index)}>Manage Open and Free Sections</a></li>
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.Ingest)}>Ingest Course Project</a></li>
          <li><a href={Routes.brand_path(OliWeb.Endpoint, :index)}>Manage Branding</a></li>
        </ul>
      </Group>
      <Group label="System Management" description="Manage and support system level functionality">
        <ul class="link-list">
          <li><a href={Routes.activity_manage_path(OliWeb.Endpoint, :index)}>Manage Activities</a></li>
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.SystemMessageLive.IndexView)}>Manage System Message Banner</a></li>
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Admin.RegistrationsView)}>Manage LTI 1.3 Registrations</a></li>
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.Features.FeaturesLive)}>Enable and Disable Feature Flags</a></li>
          <li><a href={Routes.live_path(OliWeb.Endpoint, OliWeb.ApiKeys.ApiKeysLive)}>Manage Third-Party API Keys</a></li>
          <li>
            <a href={Routes.live_dashboard_path(OliWeb.Endpoint, :home)} target="_blank">
              <span>View System Performance Dashboard</span> <i class="las la-external-link-alt align-self-center ml-1"></i>
            </a>
          </li>
        </ul>
      </Group>
    </Groups>
    """
  end

  def badge(assigns, badge) do
    case badge do
      nil ->
        ""

      badge ->
        ~F"""
        <span class="badge badge-pill badge-primary ml-2">{badge}</span>
        """
    end
  end

  def breadcrumb(),
    do: [
      Breadcrumb.new(%{link: Routes.live_path(OliWeb.Endpoint, __MODULE__), full_title: "Admin"})
    ]
end
