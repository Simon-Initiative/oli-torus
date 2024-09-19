defmodule OliWeb.Workspaces.CourseAuthor.ActivityBankLive do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Authoring.Editing.BankEditor
  alias OliWeb.Common.React
  alias OliWeb.Router.Helpers, as: Routes

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{project: project, current_author: author, ctx: ctx} = socket.assigns
    is_admin? = Accounts.at_least_content_admin?(author)

    case BankEditor.create_context(project.slug, author) do
      {:ok, context} ->
        {:ok,
         assign(socket,
           active: :bank,
           context: context,
           is_admin?: is_admin?,
           revision_history_link: is_admin?,
           scripts: Oli.Activities.get_activity_scripts(),
           resource_slug: project.slug,
           resource_title: project.title,
           ctx: ctx
         )}

      _ ->
        OliWeb.ResourceController.render_not_found(OliWeb.Endpoint, project.slug)
    end
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/activitybank.js")}>
    </script>

    <%= for script <- @scripts do %>
      <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/#{script}")}>
      </script>
    <% end %>

    <div id="editor">
      <%= React.component(
        @ctx,
        "Components.ActivityBank",
        Map.merge(@context, %{revisionHistoryLink: @revision_history_link}),
        id: "activity-bank"
      ) %>
    </div>
    <%= React.component(@ctx, "Components.ModalDisplay", %{}, id: "modal-display") %>
    """
  end
end
