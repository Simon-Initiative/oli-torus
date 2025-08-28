defmodule OliWeb.Delivery.StudentOnboarding.Survey do
  use OliWeb, :live_component

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

      # Just in time addition of the survey to the course section's section resources.
      # This was needed due to a hotfix bug that was causing the survey to not be added
      # to the section resources at publication application time.
      Oli.Delivery.Sections.Updates.ensure_section_resource_exists(
        section.slug,
        section.required_survey_resource_id
      )

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
        learning_language: base_project_attributes.learning_language,
        is_liveview: true
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
    <div id="eventIntercept" phx-target={@myself} phx-hook="LoadSurveyScripts" class="h-full">
      <script>
        window.userToken = "<%= assigns[:user_token] %>";
      </script>
      <%= if @error do %>
        <div class="alert alert-danger m-0 flex flex-row justify-between w-full" role="alert">
          Something went wrong when loading the survey
        </div>
      <% else %>
        <div class="flex py-6 px-[20px] hvsm:px-[70px] hvxl:px-[84px] gap-3">
          <div class="flex relative">
            <img
              src={~p"/images/assistant/dot_ai_icon.png"}
              alt="dot icon"
              class="w-24 absolute -top-4 -left-2"
            />
            <div class="w-14 shrink-0 mr-5" />
            <div class="flex flex-col gap-3">
              <h2 class="text-[18xl] leading-[24px] hvsm:text-[30px] hvsm:leading-[40px] hvxl:text-[40px] hvxl:leading-[54px] tracking-[0.02px] dark:text-white">
                {@title}
              </h2>
              <span class="text-[14px] leading-[20px] tracking-[0.02px] dark:text-white">
                Please complete this required survey before beginning your course.
              </span>
            </div>
          </div>
        </div>
        <%= if @loaded do %>
          <div class="px-[20px] hvsm:px-[70px] hvxl:px-[84px] py-9 h-[334px]">
            {Phoenix.HTML.raw(@html)}
          </div>
        <% else %>
          <div class="w-full flex items-center justify-center my-10 h-[334px]">
            <span
              class="spinner-border spinner-border-sm text-primary h-16 w-16"
              role="status"
              aria-hidden="true"
            />
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
