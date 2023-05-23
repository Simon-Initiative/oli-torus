defmodule OliWeb.Delivery.StudentOnboarding.Survey do
  use Phoenix.LiveComponent

  alias Oli.Delivery.Sections
  alias Oli.Resources.PageContent
  alias Oli.Rendering.Page
  alias OliWeb.Router.Helpers, as: Routes

  def update(assigns, socket) do
    if !socket.assigns[:loaded] do
      user = assigns.user
      section = assigns.section
      survey = assigns.survey
      datashop_session_id = assigns.datashop_session_id

      context =
        Oli.Delivery.Page.PageContext.create_for_visit(
          section,
          survey.slug,
          user,
          datashop_session_id
        )

      base_project_attributes = Sections.get_section_attributes(section)

      submitted_surveys =
        PageContent.survey_activities(hd(context.resource_attempts).content)
        |> Enum.reduce(%{}, fn {survey_id, activity_ids}, acc ->
          survey_state =
            Enum.all?(activity_ids, fn id ->
              context.activities[id].lifecycle_state === :submitted ||
                context.activities[id].lifecycle_state === :evaluated
            end)

          Map.put(acc, survey_id, survey_state)
        end)

      base_project_slug =
        case section.has_experiments do
          true ->
            Oli.Repo.get(Oli.Authoring.Course.Project, section.base_project_id).slug

          _ ->
            nil
        end

      enrollment =
        case section.has_experiments do
          true -> Oli.Delivery.Sections.get_enrollment(section.slug, user.id)
          _ -> nil
        end

      render_context = %Oli.Rendering.Context{
        enrollment: enrollment,
        user: user,
        section_slug: section.slug,
        project_slug: base_project_slug,
        resource_attempt: hd(context.resource_attempts),
        mode: :delivery,
        activity_map: context.activities,
        resource_summary_fn: &Oli.Resources.resource_summary(&1, section.slug, Resolver),
        alternatives_groups_fn: fn ->
          Oli.Resources.alternatives_groups(section.slug, Resolver)
        end,
        alternatives_selector_fn: &Oli.Resources.Alternatives.select/2,
        extrinsic_read_section_fn: &Oli.Delivery.ExtrinsicState.read_section/3,
        bib_app_params: context.bib_revisions,
        submitted_surveys: submitted_surveys,
        historical_attempts: context.historical_attempts,
        learning_language: base_project_attributes.learning_language
      }

      this_attempt = context.resource_attempts |> hd
      html = Page.render(render_context, this_attempt.content, Page.Html)

      all_activities = Oli.Activities.list_activity_registrations()

      script_sources =
        Enum.map(all_activities, fn a ->
          Routes.static_path(OliWeb.Endpoint, "/js/" <> a.delivery_script)
        end)

      {:ok,
       assign(socket, html: html, title: survey.title)
       |> push_event("load_survey_scripts", %{script_sources: script_sources})}
    else
      {:ok, socket}
    end
  end

  attr :title, :string, required: true
  attr :html, :any, default: nil
  attr :loaded, :boolean, default: false
  attr :error, :boolean, default: false

  attr :user, :map, required: true
  attr :section, :map, required: true
  attr :survey, :map, required: true
  attr :datashop_session_id, :string, required: true
  def render(assigns) do
    ~H"""
      <div id="eventIntercept" phx-hook="LoadSurveyScripts" class="h-full">
        <script>
          window.userToken = "<%= assigns[:user_token] %>";
        </script>
        <%= if @error do %>
          <div class="alert alert-danger m-0 flex flex-row justify-between w-full" role="alert">
            Something went wrong when loading the survey
          </div>
        <% else %>
          <%= if @loaded do %>
            <h1 class="mb-4"><%= @title %></h1>
            <hr class="text-gray-400 my-4">
            <div class="pb-1">
              <%= Phoenix.HTML.raw(@html) %>
            </div>
          <% else %>
            <div class="h-full w-full flex items-center justify-center">
              <span class="spinner-border spinner-border-sm text-primary h-16 w-16" role="status" aria-hidden="true" />
            </div>
          <% end %>
        <% end %>
      </div>
    """
  end

  def handle_event("survey_scripts_loaded", %{"error" => _}, socket) do
    {:noreply, assign(socket, error: true)}
  end

  def handle_event("survey_scripts_loaded", _params, socket) do
    {:noreply, assign(socket, loaded: true)}
  end
end
