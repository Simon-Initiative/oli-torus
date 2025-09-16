defmodule OliWeb.Workspaces.CourseAuthor.BibliographyLive do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias OliWeb.Common.React

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    project = socket.assigns.project
    author = socket.assigns.current_author
    is_admin? = Accounts.has_admin_role?(author, :content_admin)
    ctx = socket.assigns.ctx

    socket =
      assign(socket,
        resource_slug: project.slug,
        resource_title: project.title,
        project_slug: project.slug,
        is_admin?: is_admin?,
        active: :bibliography,
        ctx: ctx,
        context: %{},
        error: false
      )

    case Oli.Authoring.Editing.BibliographyEditor.create_context(project.slug, author) do
      {:ok, context} ->
        {:ok, assign(socket, context: context)}

      _ ->
        socket =
          socket
          |> assign(error: true)
          |> put_flash(:error, "Publication not found. Please check the URL and try again.")

        {:ok, socket}
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <h2 id="header_id" class="pb-2">Bibliography</h2>
    <div :if={!@error} id="editor" phx-update="ignore">
      {React.component(@ctx, "Components.Bibliography", @context, id: "bibliography")}
    </div>
    """
  end
end
