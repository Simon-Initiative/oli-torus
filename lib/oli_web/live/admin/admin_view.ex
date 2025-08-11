defmodule OliWeb.Admin.AdminView do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias OliWeb.Common.Properties.{Groups, Group}
  alias OliWeb.Common.Breadcrumb

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  def mount(_, _session, socket) do
    author = socket.assigns.current_author

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
              <a href={~p"/admin/users"}>
                Manage Students and Instructor Accounts
              </a>
            </li>
            <li>
              <a href={~p"/admin/authors"}>
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
            <li><a href={~p"/admin/invite"}>Invite New Authors</a></li>
            <li>
              <a href={~p"/authoring/communities"}>
                Manage Communities
              </a>
            </li>
            <li>
              <a href={~p"/admin/registrations"}>
                Manage LTI 1.3 Registrations
              </a>
            </li>
            <li>
              <a href={~p"/admin/external_tools"}>
                Manage LTI 1.3 External Tools
              </a>
            </li>
          </ul>
        </Group.render>
      <% end %>
      <%= if Accounts.is_admin?(@author) do %>
        <Group.render label="Content Management" description="Access and manage created content">
          <ul class="link-list">
            <li>
              <a href={~p"/authoring/projects"}>
                Browse all Projects
              </a>
            </li>
            <li>
              <a href={~p"/admin/products"}>
                Browse all Products
              </a>
            </li>
            <li>
              <a href={~p"/admin/sections"}>
                Browse all Course Sections
              </a>
            </li>
            <li><a href={~p"/admin/ingest/upload"}>Ingest Project</a></li>
            <li><a href={~p"/admin/brands"}>Manage Branding</a></li>
            <li>
              <a href={~p"/admin/publishers"}>
                Manage Publishers
              </a>
            </li>
            <li>
              <a href={~p"/admin/datasets"}>
                Manage Dataset Jobs
              </a>
            </li>
          </ul>
        </Group.render>
      <% end %>
      <%= if Accounts.has_admin_role?(@author, :system_admin) do %>
        <Group.render label="GenAI Features" description="Manage and support GenAI based features">
          <ul class="link-list">
            <li>
              <a href={~p"/admin/gen_ai/registered_models"}>Manage registered LLM models</a>
            </li>
            <li>
              <a href={~p"/admin/gen_ai/service_configs"}>Manage service configurations</a>
            </li>
            <li>
              <a href={~p"/admin/gen_ai/feature_configs"}>Manage feature configurations</a>
            </li>
          </ul>
        </Group.render>
        <Group.render
          label="System Management"
          description="Manage and support system level functionality"
        >
          <ul class="link-list">
            <li>
              <a href={~p"/admin/manage_activities"}>Manage Activities</a>
            </li>
            <li>
              <a href={~p"/admin/system_messages"}>
                Manage System Message Banner
              </a>
            </li>

            <li>
              <a href={~p"/admin/features"}>
                Feature Flags and Logging
              </a>
            </li>
            <li>
              <a href={~p"/admin/api_keys"}>
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
              <a href={~p"/admin/dashboard/home"} target="_blank">
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
      Breadcrumb.new(%{link: ~p"/admin", full_title: "Admin"})
    ]
end
