defmodule OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveView do
  use OliWeb, :live_component
  alias Oli.Delivery.Metrics

  attr :objective, :map, required: true
  attr :section_id, :integer, required: true
  attr :section_slug, :string, required: true
  attr :current_user, :map, required: true

  def mount(socket) do
    {:ok, socket}
  end

  def update(assigns, socket) do
    %{
      objective: objective,
      section_id: section_id,
      section_slug: section_slug
    } = assigns

    # Calculate real estimated students count based on enrolled students
    estimated_students = calculate_estimated_students(section_slug)

    sub_objectives_data = get_sub_objectives_data(section_id, section_slug, objective.resource_id)

    # Get individual student proficiency for the dot distribution chart
    student_proficiency = Metrics.student_proficiency_for_objective(section_id, objective.resource_id)
    
    # Calculate proficiency distribution for the main objective
    proficiency_per_student = Metrics.proficiency_per_student_for_objective(section_id, [objective.resource_id])
    proficiency_distribution = calculate_proficiency_distribution_from_student_data(proficiency_per_student, objective.resource_id, section_slug)

    socket =
      socket
      |> assign(assigns)
      |> assign(
        objective_id: objective.resource_id,
        objective_title: objective.title,
        estimated_students: estimated_students,
        sub_objectives_data: sub_objectives_data,
        student_proficiency: student_proficiency,
        proficiency_distribution: proficiency_distribution,
        unique_id: assigns[:unique_id] || "#{objective.resource_id}"
      )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="expanded-objective-view w-full">
      <!-- Estimated Learning Header -->
      <div class="mb-4">
        <h3 class="text-lg font-medium text-Text-text-high">
          Estimated Learning: {@estimated_students} {ngettext(
            "Student",
            "Students",
            @estimated_students
          )}
        </h3>
      </div>
      
    <!-- Proficiency Distribution Dots Chart -->
      <div class="mb-6">
        {render_dots_chart(assigns)}
      </div>
      
    <!-- Sub-objectives Table -->
      <div class="mt-4">
        <%= if @sub_objectives_data == [] do %>
          No sub-objectives found
        <% else %>
          <.live_component
            module={OliWeb.Components.Delivery.LearningObjectives.SubObjectivesList}
            id={"sub-objectives-list-#{@unique_id}"}
            objective_id={@objective_id}
            section_slug={@section_slug}
            sub_objectives_data={@sub_objectives_data}
            main_objective_title={@objective_title}
            show_back_button={false}
            expandable_charts={false}
            use_table_model={true}
          />
        <% end %>
      </div>
    </div>
    """
  end

  # RENDER DOTS CHART - Using React component for detailed visualization
  defp render_dots_chart(assigns) do
    OliWeb.Common.React.component(
      %{is_liveview: true},
      "Components.DotDistributionChart",
      %{
        proficiency_distribution: assigns.proficiency_distribution,
        student_proficiency: assigns.student_proficiency,
        objective_id: assigns.objective_id
      },
      id: "dot-distribution-chart-#{assigns.objective_id}"
    )
  end

  # Calculate the estimated number of students for this learning objective
  # This represents the total enrolled students in the section
  defp calculate_estimated_students(section_slug) do
    section_slug
    |> Oli.Delivery.Sections.enrolled_student_ids()
    |> length()
  end

  # Get real sub-objectives data from database
  defp get_sub_objectives_data(section_id, section_slug, objective_id) do
    # Use the existing Metrics function to get sub-objectives proficiency data
    sub_objectives_raw_data =
      Metrics.sub_objectives_proficiency(section_id, objective_id)

    # Transform the data to match the table model structure
    sub_objectives_raw_data
    |> Enum.map(fn %{
                     sub_objective_id: sub_obj_id,
                     title: title,
                     proficiency_distribution: distribution
                   } ->
      # Calculate overall student proficiency for this sub-objective
      student_proficiency = calculate_overall_proficiency(distribution)

      %{
        id: sub_obj_id,
        title: title,
        student_proficiency: student_proficiency,
        proficiency_distribution: distribution,
        activities_count:
          Metrics.related_activities_count_for_subobjective(section_slug, sub_obj_id)
      }
    end)
  end

  # Calculate overall proficiency based on distribution (similar to logic in sub_objectives_list.ex)
  defp calculate_overall_proficiency(proficiency_distribution) do
    total = get_total_students(proficiency_distribution)

    cond do
      total == 0 -> "Not enough data"
      Map.get(proficiency_distribution, "High", 0) / total >= 0.6 -> "High"
      Map.get(proficiency_distribution, "Medium", 0) / total >= 0.4 -> "Medium"
      true -> "Low"
    end
  end

  defp get_total_students(proficiency_distribution) do
    proficiency_distribution
    |> Map.values()
    |> Enum.sum()
  end

  # Convert proficiency per student data to distribution counts
  defp calculate_proficiency_distribution_from_student_data(proficiency_per_student, objective_id, section_slug) do
    student_proficiency_levels = Map.get(proficiency_per_student, objective_id, %{})
    
    # Get all enrolled students in the section (same logic as in sections.ex)
    all_student_ids = Oli.Delivery.Sections.enrolled_student_ids(section_slug)
    
    # Add "Not enough data" for students who don't have proficiency data 
    # (same logic as in get_objectives_and_subobjectives/3)
    complete_student_proficiency =
      all_student_ids
      |> Enum.reject(&Map.has_key?(student_proficiency_levels, &1))
      |> Enum.reduce(student_proficiency_levels, fn user_id, acc ->
        Map.put(acc, user_id, "Not enough data")
      end)
    
    # Count students by proficiency level using Enum.frequencies_by (same as original)
    complete_student_proficiency
    |> Enum.frequencies_by(fn {_student_id, proficiency_level} -> proficiency_level end)
  end
end
