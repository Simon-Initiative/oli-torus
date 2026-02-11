defmodule OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveView do
  use OliWeb, :live_component

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Accounts
  alias OliWeb.Common.Utils

  attr :unique_id, :string, required: true
  attr :objective, :map, required: true
  attr :section_id, :integer, required: true
  attr :section_slug, :string, required: true
  attr :current_user, :map, required: true
  attr :sync_load, :boolean, default: false
  attr :is_expanded, :boolean, default: false

  def mount(socket) do
    {:ok, assign(socket, loading: false)}
  end

  def update(assigns, socket) do
    cond do
      # Handle async data loading completion
      Map.has_key?(assigns, :loaded_data) ->
        loaded_data = assigns.loaded_data

        {:ok,
         socket
         |> assign(loading: false)
         |> assign(loaded_data)}

      # Handle initial render or updates
      true ->
        handle_initial_update(assigns, socket)
    end
  end

  defp handle_initial_update(assigns, socket) do
    %{
      objective: objective,
      section_id: section_id,
      section_slug: section_slug
    } = assigns

    objective_id = objective.resource_id
    is_expanded = Map.get(assigns, :is_expanded, false)
    has_loaded_data = not is_nil(socket.assigns[:estimated_students])
    already_loading = Map.get(socket.assigns, :loading, false)

    # Check if we need to load data
    # Load if: expanded AND NOT already loading AND (new objective OR no data loaded yet)
    needs_loading =
      is_expanded and
        not already_loading and
        (is_nil(socket.assigns[:objective_id]) or
           socket.assigns[:objective_id] != objective_id or
           not has_loaded_data)

    if needs_loading do
      # Get the unique_id and construct component_id before assigning
      unique_id = assigns.unique_id
      component_id = "expanded-objective-#{unique_id}"

      # Check if synchronous loading is requested
      sync_load = Map.get(assigns, :sync_load, false)

      if sync_load do
        # Load synchronously
        all_student_ids = Oli.Delivery.Sections.enrolled_student_ids(section_slug)
        estimated_students = length(all_student_ids)
        sub_objectives_data = get_sub_objectives_data(section_id, section_slug, objective_id)

        proficiency_distribution =
          section_id
          |> Metrics.proficiency_per_student_for_objective([objective_id])
          |> calculate_proficiency_distribution_from_student_data(
            objective_id,
            all_student_ids
          )

        student_proficiency =
          section_id
          |> Metrics.student_proficiency_for_objective(objective_id)
          |> retrieve_students_data()
          |> add_missing_students_to_proficiency_data(
            all_student_ids,
            section_id,
            objective_id
          )

        socket =
          socket
          |> assign(assigns)
          |> assign(
            loading: false,
            objective_id: objective_id,
            objective_title: objective.title,
            selected_proficiency_level: nil,
            estimated_students: estimated_students,
            sub_objectives_data: sub_objectives_data,
            student_proficiency: student_proficiency,
            proficiency_distribution: proficiency_distribution
          )

        {:ok, socket}
      else
        # Load asynchronously (default behavior)
        socket =
          socket
          |> assign(assigns)
          |> assign(
            loading: true,
            objective_id: objective_id,
            objective_title: objective.title,
            selected_proficiency_level: nil
          )

        # Schedule async data loading
        pid = self()

        Task.start(fn ->
          # Get all enrolled students in the section (excludes instructors)
          all_student_ids = Oli.Delivery.Sections.enrolled_student_ids(section_slug)

          # Calculate real estimated students count based on enrolled students
          estimated_students = length(all_student_ids)

          # Fetch sub-objectives data for the main objective
          sub_objectives_data = get_sub_objectives_data(section_id, section_slug, objective_id)

          # Calculate proficiency distribution for the main objective
          proficiency_distribution =
            section_id
            |> Metrics.proficiency_per_student_for_objective([objective_id])
            |> calculate_proficiency_distribution_from_student_data(
              objective_id,
              all_student_ids
            )

          # Get individual student proficiency for the dot distribution chart
          # Start with real proficiency data and add missing students to ensure consistency
          student_proficiency =
            section_id
            |> Metrics.student_proficiency_for_objective(objective_id)
            |> retrieve_students_data()
            |> add_missing_students_to_proficiency_data(
              all_student_ids,
              section_id,
              objective_id
            )

          # Send message to parent process
          send(
            pid,
            {__MODULE__, component_id,
             %{
               estimated_students: estimated_students,
               sub_objectives_data: sub_objectives_data,
               student_proficiency: student_proficiency,
               proficiency_distribution: proficiency_distribution
             }}
          )
        end)

        {:ok, socket}
      end
    else
      # Data already loaded, just update assigns
      {:ok, assign(socket, assigns)}
    end
  end

  def handle_event("show_students_list", %{"proficiency_level" => proficiency_level}, socket) do
    {:noreply, assign(socket, selected_proficiency_level: proficiency_level)}
  end

  def handle_event("hide_students_list", _params, socket) do
    {:noreply, assign(socket, selected_proficiency_level: nil)}
  end

  def render(assigns) do
    # Safely check if data is loaded
    has_data =
      Map.has_key?(assigns, :estimated_students) and not is_nil(assigns.estimated_students)

    assigns = assign(assigns, :has_data, has_data)

    ~H"""
    <div id={"expanded-objective-#{@unique_id}"} class="expanded-objective-view w-full">
      <%= cond do %>
        <% @is_expanded and @loading -> %>
          <!-- Loading Spinner - only show when expanded and loading -->
          <div class="flex justify-center items-center py-8">
            <span
              class="spinner-border spinner-border-sm h-8 w-8 text-Text-text-button"
              role="status"
              aria-hidden="true"
            >
            </span>
          </div>
        <% @is_expanded and @has_data -> %>
          <!-- Show content only when expanded AND data is loaded -->
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
          
    <!-- Student Proficiency List (when a level is selected) -->
          <%= if @selected_proficiency_level do %>
            <div class="mb-6">
              <.live_component
                module={OliWeb.Components.Delivery.LearningObjectives.StudentProficiencyList}
                id={"student-proficiency-list-#{@unique_id}"}
                selected_proficiency_level={@selected_proficiency_level}
                student_proficiency={@student_proficiency}
                section_slug={@section_slug}
                section_title={@section_title}
                instructor_email={@current_user.email}
                instructor_name={Utils.name(@current_user)}
              />
            </div>
          <% end %>
          
    <!-- Sub-objectives Table (always shown) -->
          <div id={"sub-objectives-list-container-#{@unique_id}"} class="mt-4">
            <%= if @sub_objectives_data == [] do %>
              No sub-objectives found
            <% else %>
              <.live_component
                module={OliWeb.Components.Delivery.LearningObjectives.SubObjectivesList}
                id={"sub-objectives-list-#{@unique_id}"}
                sub_objectives_data={@sub_objectives_data}
                parent_unique_id={@unique_id}
              />
            <% end %>
          </div>
        <% true -> %>
          <!-- Not expanded or no data - show nothing (data remains cached) -->
          <div></div>
      <% end %>
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
        unique_id: assigns.unique_id
      },
      id: "dot-distribution-chart-#{assigns.unique_id}"
    )
  end

  # Get real sub-objectives data using optimized depot approach
  defp get_sub_objectives_data(section_id, section_slug, objective_id) do
    # Fetch sub-objectives proficiency data
    sub_objectives_raw_data = sub_objectives_proficiency(section_id, section_slug, objective_id)

    # Extract all sub-objective IDs for batch activity count query
    sub_objective_ids = Enum.map(sub_objectives_raw_data, & &1.sub_objective_id)

    # Get activities count from related_activities field using depot batch query
    activities_count =
      SectionResourceDepot.get_resources_by_ids(section_id, sub_objective_ids)
      |> Enum.reduce(%{}, fn section_resource, acc ->
        Map.put(
          acc,
          section_resource.resource_id,
          length(section_resource.related_activities || [])
        )
      end)

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
        activities_count: Map.get(activities_count, sub_obj_id, 0)
      }
    end)
  end

  defp sub_objectives_proficiency(section_id, section_slug, objective_id) do
    # Step 1: Get the parent objective section resource from the depot
    with parent_objective when not is_nil(parent_objective) <-
           SectionResourceDepot.get_section_resource(section_id, objective_id),
         # Note: This line will become obsolete once we start storing children directly in the section_resources table
         parent_objective_revision when not is_nil(parent_objective_revision) <-
           Oli.Resources.get_revision!(parent_objective.revision_id),
         %{children: sub_objective_ids}
         when not is_nil(sub_objective_ids) and sub_objective_ids != [] <-
           parent_objective_revision do
      # Step 2: Get the sub-objectives section resources from the depot
      sub_objective_section_resources =
        SectionResourceDepot.get_resources_by_ids(section_id, sub_objective_ids)

      # Step 3: Call the optimized objectives_proficiency function
      Metrics.objectives_proficiency(section_id, section_slug, sub_objective_section_resources)
    else
      _ -> []
    end
  end

  # Calculate overall proficiency based on distribution using the same logic as objectives
  defp calculate_overall_proficiency(proficiency_distribution) do
    total = get_total_students(proficiency_distribution)

    if total == 0 do
      "Not enough data"
    else
      # Find the most frequent proficiency level (mode)
      proficiency_distribution
      |> Enum.map(fn {key, value} ->
        ordinal =
          case String.downcase(key) do
            "low" -> 0
            "medium" -> 1
            "high" -> 2
            _ -> 3
          end

        {key, value, ordinal}
      end)
      |> Enum.sort_by(fn {_key, _value, ordinal} -> ordinal end)
      |> Enum.max_by(fn {_key, value, _ordinal} -> value end)
      |> elem(0)
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
    student_set = MapSet.new(all_student_ids)

    filtered_student_proficiency_levels =
      student_proficiency_levels
      |> Enum.filter(fn {user_id, _proficiency_level} -> MapSet.member?(student_set, user_id) end)
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

  # Retrieve and merge students data.
  defp retrieve_students_data(student_proficiency) do
    students_by_id =
      student_proficiency
      |> Enum.map(& &1.id)
      |> Accounts.get_users_by_ids()
      |> Enum.reduce(%{}, &Map.put(&2, &1.id, &1))

    student_proficiency
    |> Enum.reduce([], fn student_data, acc ->
      case students_by_id[student_data.id] do
        nil ->
          acc

        student ->
          student_full_name = Utils.name(student.name, student.given_name, student.family_name)

          student_data =
            Map.merge(student_data, %{
              email: student.email,
              full_name: student_full_name,
              name: student.name,
              given_name: student.given_name,
              family_name: student.family_name
            })

          [student_data | acc]
      end
    end)
  end

  # Add missing students to proficiency data to ensure consistency with proficiency_distribution
  # This takes real proficiency data and adds students who don't have any proficiency data
  defp add_missing_students_to_proficiency_data(
         real_student_proficiency,
         all_student_ids,
         section_id,
         objective_id
       ) do
    # Filter proficiency data to only include enrolled students (exclude instructors)
    student_set = MapSet.new(all_student_ids)

    filtered_student_proficiency =
      Enum.filter(real_student_proficiency, fn student ->
        MapSet.member?(student_set, student.id)
      end)

    # Create a set of student IDs that already have proficiency data
    existing_student_ids =
      MapSet.new(filtered_student_proficiency, fn student ->
        student.id
      end)

    # Get related_activity_ids for calculating student attempts
    related_activity_ids =
      case SectionResourceDepot.get_section_resource(section_id, objective_id) do
        nil -> []
        section_resource -> section_resource.related_activities || []
      end

    total_related_activities = length(related_activity_ids)

    # Calculate activities attempted per student
    student_activities_attempted =
      Metrics.student_activities_attempted_count(
        section_id,
        all_student_ids,
        related_activity_ids
      )

    # Add activity attempt data to existing students
    student_proficiency =
      filtered_student_proficiency
      |> Enum.map(fn student ->
        activities_attempted = Map.get(student_activities_attempted, student.id, 0)

        Map.merge(student, %{
          activities_attempted_count: activities_attempted,
          total_related_activities: total_related_activities
        })
      end)

    # Find students that are missing from proficiency data
    missing_students =
      all_student_ids
      |> get_missing_students(existing_student_ids)
      |> Enum.map(fn student ->
        activities_attempted = Map.get(student_activities_attempted, student.id, 0)
        student_full_name = Utils.name(student.name, student.given_name, student.family_name)

        %{
          id: student.id,
          email: student.email,
          full_name: student_full_name,
          name: student.name,
          given_name: student.given_name,
          family_name: student.family_name,
          proficiency: 0.0,
          proficiency_range: "Not enough data",
          activities_attempted_count: activities_attempted,
          total_related_activities: total_related_activities
        }
      end)

    # Combine final proficiency data with missing students
    student_proficiency ++ missing_students
  end

  defp get_missing_students(all_student_ids, existing_student_ids) do
    missing_student_ids = Enum.reject(all_student_ids, &MapSet.member?(existing_student_ids, &1))

    Accounts.get_users_by_ids(missing_student_ids)
  end
end
