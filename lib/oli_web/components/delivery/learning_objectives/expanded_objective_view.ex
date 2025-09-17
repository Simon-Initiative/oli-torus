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

    # Get all enrolled students in the section (excludes instructors)
    all_student_ids = Oli.Delivery.Sections.enrolled_student_ids(section_slug)

    # Calculate real estimated students count based on enrolled students
    estimated_students = length(all_student_ids)

    # Fetch sub-objectives data for the main objective
    sub_objectives_data = get_sub_objectives_data(section_id, section_slug, objective.resource_id)

    # Calculate proficiency distribution for the main objective
    proficiency_distribution =
      section_id
      |> Metrics.proficiency_per_student_for_objective([objective.resource_id])
      |> calculate_proficiency_distribution_from_student_data(
        objective.resource_id,
        all_student_ids
      )

    # Get individual student proficiency for the dot distribution chart
    # Start with real proficiency data and add missing students to ensure consistency
    student_proficiency =
      section_id
      |> Metrics.student_proficiency_for_objective(objective.resource_id)
      |> add_missing_students_to_proficiency_data(all_student_ids)

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
  defp calculate_proficiency_distribution_from_student_data(
         proficiency_per_student,
         objective_id,
         all_student_ids
       ) do
    student_proficiency_levels = Map.get(proficiency_per_student, objective_id, %{})

    # Filter proficiency data to only include enrolled students (exclude instructors)
    filtered_student_proficiency_levels =
      student_proficiency_levels
      |> Enum.filter(fn {user_id, _proficiency_level} -> user_id in all_student_ids end)
      |> Map.new()

    # Add "Not enough data" for students who don't have proficiency data
    complete_student_proficiency =
      all_student_ids
      |> Enum.reject(&Map.has_key?(filtered_student_proficiency_levels, &1))
      |> Enum.reduce(filtered_student_proficiency_levels, fn user_id, acc ->
        Map.put(acc, user_id, "Not enough data")
      end)

    # Count students by proficiency level using Enum.frequencies_by
    complete_student_proficiency
    |> Enum.frequencies_by(fn {_student_id, proficiency_level} -> proficiency_level end)
  end

  # Add missing students to proficiency data to ensure consistency with proficiency_distribution
  # This takes real proficiency data and adds students who don't have any proficiency data
  defp add_missing_students_to_proficiency_data(real_student_proficiency, all_student_ids) do
    # Filter proficiency data to only include enrolled students (exclude instructors)
    filtered_student_proficiency =
      real_student_proficiency
      |> Enum.filter(fn student -> String.to_integer(student.student_id) in all_student_ids end)

    # Create a set of student IDs that already have proficiency data
    existing_student_ids =
      MapSet.new(filtered_student_proficiency, fn student ->
        String.to_integer(student.student_id)
      end)

    # Find students that are missing from proficiency data
    missing_students =
      all_student_ids
      |> Enum.reject(&MapSet.member?(existing_student_ids, &1))
      |> Enum.map(fn student_id ->
        %{
          student_id: Integer.to_string(student_id),
          proficiency: 0.0,
          proficiency_range: "Not enough data"
        }
      end)

    # Combine filtered proficiency data with missing students
    filtered_student_proficiency ++ missing_students
  end
end
