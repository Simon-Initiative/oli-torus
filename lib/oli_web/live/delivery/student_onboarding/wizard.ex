defmodule OliWeb.Delivery.StudentOnboarding.Wizard do
  use Phoenix.LiveView

  import OliWeb.Common.SourceImage

  alias OliWeb.Common.Stepper
  alias OliWeb.Common.Stepper.Step
  alias Phoenix.LiveView.JS

  @intro_step :intro
  @survey_step :survey
  @explorations_step :explorations
  @course_step :course

  @survey_label "Start survey"
  @explorations_label "Go to explorations"
  @course_label "Go to course"

  def mount(_params, _session, socket) do
    section = socket.assigns.section

    has_required_survey = has_required_survey(section)
    has_explorations = has_explorations(section)

    introduction_step = %Step{
      title: "Introduction",
      description:
        "Welcome to Chemistry 101! Here's what you can expect during this set up process.",
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
            JS.push("change_step", value: %{current_step_label: @survey_step})

          ^has_explorations ->
            JS.push("change_step", value: %{current_step_label: @explorations_step})

          _ ->
            JS.push("change_step", value: %{current_step_label: @course_step})
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
          true -> JS.push("change_step", value: %{current_step_label: @explorations_step})
          _ -> JS.push("change_step", value: %{current_step_label: @course_step})
        end,
      on_previous_step: JS.push("change_step", value: %{current_step_label: @intro_step})
    }

    exploration_step = %Step{
      title: "Explorations",
      description: "An introduction to Explorations -- real world chemistry applications.",
      render_fn: &render_step/1,
      data: %{},
      next_button_label: @course_label,
      on_next_step: JS.push("change_step", value: %{current_step_label: @course_step}),
      on_previous_step:
        case has_required_survey do
          true -> JS.push("change_step", value: %{current_step_label: @survey_step})
          _ -> JS.push("change_step", value: %{current_step_label: @intro_step})
        end
    }

    steps =
      case {has_required_survey(section), has_explorations(section)} do
        {true, true} -> [introduction_step, required_survey_step, exploration_step]
        {true, false} -> [introduction_step, required_survey_step]
        {false, true} -> [introduction_step, exploration_step]
        _ -> [introduction_step]
      end

    {:ok, assign(socket, steps: steps, current_step_label: @intro_step, current_step_index: 0)}
  end

  attr :section, :map, required: true
  attr :steps, :list, default: []
  attr :current_step_label, :atom, default: @intro_step
  attr :current_step_index, :integer, default: 0

  def render(assigns) do
    ~H"""
      <div>
        <.live_component
          id="student-onboarding-wizard"
          module={Stepper}
          steps={@steps}
          current_step={@current_step_index}
          data={get_step_data(assigns)}
        />
      </div>
    """
  end

  slot :inner_block, required: true
  attr :section, :map, required: true

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

  attr :section, :map, required: true

  def render_step(%{current_step_label: @intro_step} = assigns) do
    ~H"""
      <.header section={@section}>
        <div class="flex flex-col gap-6">
          <img class="object-cover h-80 w-full" src={cover_image(@section)} />
          <h2>Welcome to <%= @section.title %>!</h2>
          <div>
            <p class="font-bold mb-0">Here's what to expect</p>
            <ul class="list-disc ml-6">
              <%= if has_required_survey(@section) do %>
                <li>A 5 minute survey to help shape learning your experience and let your instructor get to know you</li>
              <% end %>
              <%= if has_explorations(@section) do %>
                <li>Learning about the new 'Exploration' activities that provide real-world examples</li>
              <% end %>
              <li>A personalized <%= @section.title %> experience based on your skillsets</li>
            </ul>
          </div>
        </div>
      </.header>
    """
  end

  def render_step(%{current_step_label: @survey_step} = assigns) do
    ~H"""
      <div>Survey</div>
    """
  end

  def render_step(%{current_step_label: @explorations_step} = assigns) do
    ~H"""
      <div>Explorations</div>
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

  def handle_event("change_step", %{"current_step_label" => current_step_label}, socket) do
    current_step_label = String.to_existing_atom(current_step_label)

    {:noreply,
     assign(socket,
       current_step_label: current_step_label,
       current_step_index: get_step_index(current_step_label, socket)
     )}
  end

  defp get_step_data(assigns) do
    case assigns.current_step_label do
      @intro_step ->
        %{
          section: assigns.section,
          current_step_label: assigns.current_step_label
        }

      _ ->
        %{
          section: assigns.section,
          current_step_label: assigns.current_step_label
        }
    end
  end

  defp has_required_survey(section) do
    !is_nil(section.required_survey_resource_id)
  end

  defp has_explorations(section) do
    section.contains_explorations
  end
end
