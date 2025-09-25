defmodule OliWeb.Workspaces.CourseAuthor.ActivityBankLive do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Authoring.Editing.BankEditor
  alias OliWeb.Common.React

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    %{project: project, current_author: author, ctx: ctx} = socket.assigns
    is_admin? = Accounts.at_least_content_admin?(author)

    case BankEditor.create_context(project.slug, author) do
      {:ok, context} ->
        scripts = Oli.Activities.get_activity_scripts() |> Enum.map(&"/js/#{&1}")

        assign(socket,
          maybe_scripts_loaded: false,
          scripts: scripts,
          error: false,
          active: :bank,
          context: context,
          is_admin?: is_admin?,
          revision_history_link: is_admin?,
          resource_slug: project.slug,
          resource_title: project.title,
          ctx: ctx
        )
        |> push_event("load_survey_scripts", %{script_sources: scripts})
        |> then(fn socket -> {:ok, socket} end)

      _ ->
        OliWeb.ResourceController.render_not_found(OliWeb.Endpoint, project.slug)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="eventIntercept" phx-hook="LoadSurveyScripts">
      <h2 id="header_id" class="pb-2">Activity Bank</h2>
      <%= if connected?(@socket) and assigns[:maybe_scripts_loaded] do %>
        <.maybe_show_error error={@error} />
        <div id="editor">
          {React.component(
            @ctx,
            "Components.ActivityBank",
            Map.merge(@context, %{revisionHistoryLink: @revision_history_link}),
            id: "activity-bank"
          )}
        </div>
      <% else %>
        <.loader />
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("survey_scripts_loaded", %{"error" => _}, socket) do
    {:noreply, assign(socket, error: true, maybe_scripts_loaded: true)}
  end

  def handle_event("survey_scripts_loaded", _params, socket) do
    {:noreply, assign(socket, maybe_scripts_loaded: true)}
  end

  attr :error, :boolean, required: true

  defp maybe_show_error(assigns) do
    ~H"""
    <div :if={@error} class="alert alert-danger m-0 flex flex-row justify-between w-full" role="alert">
      Something went wrong when loading the activity bank
    </div>
    """
  end
end
