defmodule OliWeb.Delivery.StudentOnboarding.Wizard do
  use OliWeb, :live_view

  alias OliWeb.Common.Stepper
  alias OliWeb.Common.Stepper.Step
  alias OliWeb.Delivery.StudentOnboarding.{Explorations, Intro, Survey}
  alias OliWeb.Router.Helpers, as: Routes

  alias Phoenix.LiveView.JS

  @intro_step :intro
  @survey_step :survey
  @explorations_step :explorations
  @course_step :course

  @survey_label "Start survey"
  @explorations_label "Go to explorations"
  @course_label "Go to course"

  def mount(_params, %{"datashop_session_id" => datashop_session_id}, socket) do
    section = socket.assigns.section

    has_required_survey = has_required_survey(section)
    has_explorations = has_explorations(section)

    introduction_step = %Step{
      title: "Introduction",
      description:
        "Welcome to #{section.title}! Here's what you can expect during this set up process.",
      render_fn: &render_step/1,
      data: %{},
      next_button_label:
        case true do
          ^has_required_survey -> @survey_label
          ^has_explorations -> @explorations_label
          _ -> @course_label
        end,
      on_next_step:
        case true do
          ^has_required_survey ->
            JS.push("change_step", value: %{current_step_name: @survey_step})

          ^has_explorations ->
            JS.push("change_step", value: %{current_step_name: @explorations_step})

          _ ->
            JS.push("change_step", value: %{current_step_name: @course_step})
        end
    }

    required_survey_step = %Step{
      title: "Tell us more about you",
      description:
        "Answer some questions to help your instructor get to know you and to personalize your course experience.",
      render_fn: &render_step/1,
      data: %{},
      next_button_label: if(has_explorations, do: @explorations_label, else: @course_label),
      on_next_step:
        case has_explorations do
          true -> JS.push("change_step", value: %{current_step_name: @explorations_step})
          _ -> JS.push("change_step", value: %{current_step_name: @course_step})
        end,
      on_previous_step: JS.push("change_step", value: %{current_step_name: @intro_step})
    }

    exploration_step = %Step{
      title: "Explorations",
      description: "An introduction to Explorations -- real world applications.",
      render_fn: &render_step/1,
      data: %{},
      next_button_label: @course_label,
      on_next_step: JS.push("change_step", value: %{current_step_name: @course_step}),
      on_previous_step:
        case has_required_survey do
          true -> JS.push("change_step", value: %{current_step_name: @survey_step})
          _ -> JS.push("change_step", value: %{current_step_name: @intro_step})
        end
    }

    steps =
      case {has_required_survey(section), has_explorations(section)} do
        {true, true} -> [introduction_step, required_survey_step, exploration_step]
        {true, false} -> [introduction_step, required_survey_step]
        {false, true} -> [introduction_step, exploration_step]
        _ -> [introduction_step]
      end

    {:ok,
     assign(socket,
       steps: steps,
       current_step_name: @intro_step,
       current_step_index: 0,
       datashop_session_id: datashop_session_id,
       is_lti: section.open_and_free == false
     )}
  end

  attr(:section, :map, required: true)
  attr(:steps, :list, default: [])
  attr(:current_step_name, :atom, default: @intro_step)
  attr(:current_step_index, :integer, default: 0)

  def render(assigns) do
    ~H"""
      <div>
        <.live_component
          id="student-onboarding-wizard"
          module={Stepper}
          steps={@steps}
          current_step={@current_step_index}
          on_cancel={if !@is_lti, do: JS.navigate(~p"/sections"), else: nil}
          data={get_step_data(assigns)}
        />
      </div>
    """
  end

  slot(:inner_block, required: true)
  attr(:section, :map, required: true)

  defp header(assigns) do
    ~H"""
      <h5 class="px-9 py-4 border-gray-200 dark:border-gray-600 border-b text-sm font-semibold">
        <%= @section.title %> Set Up
      </h5>
      <div class="overflow-y-auto scrollbar-hide relative h-full px-10 py-4">
        <%= render_slot(@inner_block) %>
      </div>
    """
  end

  attr(:section, :map, required: true)

  def render_step(%{current_step_name: @intro_step} = assigns) do
    ~H"""
      <.header section={@section}>
        <Intro.render section={@section} />
      </.header>
    """
  end

  def render_step(%{current_step_name: @survey_step} = assigns) do
    ~H"""
      <.header section={@section}>
        <.live_component
          id="onboarding_wizard_survey"
          module={Survey}
          user={@user} section={@section} survey={@survey} datashop_session_id={@datashop_session_id} />
      </.header>
    """
  end

  def render_step(%{current_step_name: @explorations_step} = assigns) do
    ~H"""
      <.header section={@section}>
        <Explorations.render />
      </.header>
    """
  end

  defp get_step_index(step, socket) do
    section = socket.assigns.section

    case {has_required_survey(section), has_explorations(section), step} do
      {_, _, @intro_step} -> 0
      {_, _, @survey_step} -> 1
      {true, _, @explorations_step} -> 2
      {_, _, @explorations_step} -> 1
      {true, true, @course_step} -> 3
      {_, true, @course_step} -> 2
      {_, _, @course_step} -> 1
      _ -> nil
    end
  end

  def handle_event("change_step", %{"current_step_name" => current_step_name}, socket) do
    current_step_name = String.to_existing_atom(current_step_name)

    if current_step_name == @course_step do
      Oli.Delivery.Sections.mark_section_visited_for_student(
        socket.assigns.section,
        socket.assigns.current_user
      )

      {:noreply,
       push_navigate(socket,
         to: Routes.page_delivery_path(socket, :index, socket.assigns.section.slug)
       )}
    else
      {:noreply,
       assign(socket,
         current_step_name: current_step_name,
         current_step_index: get_step_index(current_step_name, socket)
       )}
    end
  end

  defp get_step_data(assigns) do
    case assigns.current_step_name do
      @intro_step ->
        %{
          section: assigns.section,
          current_step_name: assigns.current_step_name
        }

      @survey_step ->
        %{
          section: assigns.section,
          current_step_name: assigns.current_step_name,
          user: assigns.current_user,
          survey: assigns.section.required_survey,
          datashop_session_id: assigns.datashop_session_id
        }

      _ ->
        %{
          section: assigns.section,
          current_step_name: assigns.current_step_name
        }
    end
  end

  def has_required_survey(section) do
    !is_nil(section.required_survey_resource_id)
  end

  def has_explorations(section) do
    section.contains_explorations
  end
end
