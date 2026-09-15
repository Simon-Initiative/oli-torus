defmodule OliWeb.Components.Delivery.LearningObjectives.ExpandedObjectiveView do
  @moduledoc """
  Owns the expanded-row lifecycle for a Learning Objective in the instructor dashboard's
  Learning Objectives table: loading per-student proficiency/activity data (synchronously or
  asynchronously) only while the row is expanded, classifying students into distribution
  groups, tracking which group is currently selected, and rendering the Student Distribution
  matrix and the sub-objectives table for that row.
  """

  use OliWeb, :live_component

  alias Oli.Delivery.Metrics
  alias Oli.Delivery.Metrics.StudentDistributionGroup
  alias Oli.Delivery.Sections.SectionResourceDepot
  alias Oli.Accounts
  alias OliWeb.Common.Utils
  alias OliWeb.Components.Delivery.LearningObjectives.StudentDistributionMatrix

  attr :unique_id, :string, required: true
  attr :objective, :map, required: true
  attr :section_id, :integer, required: true
  attr :section_slug, :string, required: true
  attr :current_user, :map, required: true
  attr :text_search, :string, default: nil
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

        student_proficiency =
          section_id
          |> Metrics.student_proficiency_for_objective(objective_id)
          |> retrieve_students_data()
          |> add_missing_students_to_proficiency_data(
            all_student_ids,
            section_id,
            objective_id
          )
          |> StudentDistributionGroup.assign()

        socket =
          socket
          |> assign(assigns)
          |> assign(
            loading: false,
            objective_id: objective_id,
            objective_title: objective.title,
            selected_student_group: nil,
            estimated_students: estimated_students,
            sub_objectives_data: sub_objectives_data,
            student_proficiency: student_proficiency
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
            selected_student_group: nil
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

          # Get individual student proficiency for the Student Distribution matrix.
          # Start with real proficiency data, add missing students to ensure consistency
          # with enrollment, then classify each student into a distribution group.
          student_proficiency =
            section_id
            |> Metrics.student_proficiency_for_objective(objective_id)
            |> retrieve_students_data()
            |> add_missing_students_to_proficiency_data(
              all_student_ids,
              section_id,
              objective_id
            )
            |> StudentDistributionGroup.assign()

          # Send message to parent process
          send(
            pid,
            {__MODULE__, component_id,
             %{
               estimated_students: estimated_students,
               sub_objectives_data: sub_objectives_data,
               student_proficiency: student_proficiency
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

  # Fired by StudentDistributionMatrix's region phx-click/phx-keydown bindings. A phx-keydown
  # payload also carries a "key" field; only Enter and Space should activate the region so
  # unrelated keydown events (e.g. Tab, arrow keys) while a region has focus are ignored.
  def handle_event("select_student_group", %{"group" => group} = params, socket) do
    with true <- Map.get(params, "key") in [nil, "Enter", " "],
         group when not is_nil(group) <- parse_group(group) do
      selected_student_group =
        if Map.get(socket.assigns, :selected_student_group) == group, do: nil, else: group

      {:noreply, assign(socket, selected_student_group: selected_student_group)}
    else
      _ -> {:noreply, socket}
    end
  end

  # No rendered control currently calls this event -- `StudentDistributionMatrix` only emits
  # "select_student_group", which already toggles a group off when it is re-activated. This
  # handler exists as a ready, tested target for a future explicit close/dismiss control.
  def handle_event("deselect_student_group", _params, socket) do
    {:noreply, assign(socket, selected_student_group: nil)}
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
          <div class="mb-[14px]">
            <h3 class="font-open-sans text-[16px] font-bold leading-6">
              <span class="text-Text-text-low-alpha">Student Distribution: </span>
              <span class="text-Text-text-high">
                {@estimated_students} {ngettext(
                  "Student",
                  "Students",
                  @estimated_students
                )}
              </span>
            </h3>
          </div>
          
    <!-- Student Distribution Matrix: pure HEEx/SVG, no React or client-side charting library. -->
          <div class="mb-6">
            <StudentDistributionMatrix.matrix
              students={@student_proficiency}
              selected_group={@selected_student_group}
              myself={@myself}
              unique_id={@unique_id}
            />
          </div>
          
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
                text_search={@text_search}
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

  # Adds students missing from the analytics-derived proficiency data so the resulting list
  # covers every enrolled student, and attaches each student's activity-attempt counts.
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

    # Get related_activity_ids for calculating student attempts: the union of the top-level
    # objective's own related activities and those of its effective sub-objectives, not just
    # the objective's direct array -- see `linked_activity_ids_for_objective/2`.
    related_activity_ids = linked_activity_ids_for_objective(section_id, objective_id)

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

  # Resolves the unique linked-activity resource ids for a top-level objective, unioning its
  # own `related_activities` with those of its effective sub-objectives. `related_activities`
  # is direct-only (an objective's array does not include activities attached only to one of
  # its sub-objectives), so a top-level objective needs this union to answer "how many
  # activities are linked to this objective or any of its sub-objectives?" Both Depot calls
  # are cache reads -- zero database queries once the section depot is initialized.
  defp linked_activity_ids_for_objective(section_id, objective_id) do
    case SectionResourceDepot.objectives_with_effective_children_for(section_id, [objective_id]) do
      [%{children: child_ids}] ->
        [objective_id | List.wrap(child_ids)]
        |> then(&SectionResourceDepot.get_resources_by_ids(section_id, &1))
        |> Enum.flat_map(&(&1.related_activities || []))
        |> Enum.uniq()

      [] ->
        []
    end
  end

  defp get_missing_students(all_student_ids, existing_student_ids) do
    missing_student_ids = Enum.reject(all_student_ids, &MapSet.member?(existing_student_ids, &1))

    Accounts.get_users_by_ids(missing_student_ids)
  end

  @distribution_groups ~w(needs_support excelling limited_activity)a

  defp parse_group(group) when is_binary(group) do
    Enum.find(@distribution_groups, &(Atom.to_string(&1) == group))
  end

  defp parse_group(_group), do: nil
end
