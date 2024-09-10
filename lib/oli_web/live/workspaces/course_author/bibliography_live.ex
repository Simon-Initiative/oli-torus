defmodule OliWeb.Workspaces.CourseAuthor.BibliographyLive do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias OliWeb.Common.React

  on_mount {OliWeb.LiveSessionPlugs.AuthorizeProject, :default}

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    project = socket.assigns.project
    author = socket.assigns.current_author
    is_admin? = Accounts.has_admin_role?(author)
    ctx = socket.assigns.ctx

    socket =
      assign(socket,
        resource_slug: project.slug,
        resource_title: project.title,
        project_slug: project.slug,
        active_workspace: :course_author,
        active_view: :bibliography,
        is_admin?: is_admin?,
        active: :bibliography,
        ctx: ctx
      )

    case Oli.Authoring.Editing.BibliographyEditor.create_context(project.slug, author) do
      {:ok, context} ->
        socket = assign(socket, context: context, scripts: Oli.Activities.get_activity_scripts())
        {:ok, socket}

      _ ->
        socket =
          socket
          |> assign(context: %{}, scripts: [])
          |> put_flash(:error, "Publication not found. Please check the URL and try again.")

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div>
      <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/bibliography.js")}>
      </script>
      <script
        :for={script <- @scripts}
        type="text/javascript"
        src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}
      >
      </script>

      <div id="editor" phx-update="ignore">
        <%= React.component(@ctx, "Components.Bibliography", @context, id: "bibliography") %>
      </div>

      <%= React.component(@context, "Components.ModalDisplay", %{}, id: "modal-display") %>
    </div>
    """
  end
end
