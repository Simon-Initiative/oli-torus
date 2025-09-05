defmodule Oli.Scenarios.Directives.AssertProgressHandler do
  @moduledoc """
  Handles assert_progress directives for verifying student progress in pages or containers.
  
  This handler uses Oli.Delivery.Metrics to calculate progress for:
  - Individual students or all enrolled students
  - Specific pages or entire containers
  """

  alias Oli.Scenarios.DirectiveTypes.{ExecutionState, AssertProgressDirective, VerificationResult}
  alias Oli.Delivery.Metrics
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Delivery.Sections
  alias Lti_1p3.Roles.ContextRoles
  alias Oli.Repo
  import Ecto.Query

  @doc """
  Handles an assert_progress directive by calculating and verifying progress.
  
  Returns {:ok, state, verification_result} on completion, {:error, reason} on failure.
  """
  def handle(%AssertProgressDirective{} = directive, %ExecutionState{} = state) do
    with {:ok, section} <- get_section(state, directive.section),
         {:ok, resource_id} <- get_resource_id(section, directive.page || directive.container),
         {:ok, user_ids} <- get_user_ids(state, directive.student, section),
         actual_progress <- calculate_progress(section, resource_id, user_ids, directive) do
      
      # Allow a small tolerance for floating point comparison
      tolerance = 0.001
      
      if abs(actual_progress - directive.progress) < tolerance do
        {:ok, state, %VerificationResult{
          passed: true,
          message: format_success_message(directive, actual_progress),
          expected: directive.progress,
          actual: actual_progress
        }}
      else
        {:ok, state, %VerificationResult{
          passed: false,
          message: format_failure_message(directive, actual_progress),
          expected: directive.progress,
          actual: actual_progress
        }}
      end
    else
      {:error, reason} ->
        {:error, "Failed to assert progress: #{reason}"}
    end
  end

  # Get section from state
  defp get_section(state, section_name) do
    case Map.get(state.sections, section_name) do
      nil -> {:error, "Section '#{section_name}' not found"}
      section -> {:ok, section}
    end
  end

  # Get resource ID by title (page or container)
  defp get_resource_id(section, title) when is_binary(title) do
    # Get the full hierarchy to find the resource by title
    hierarchy = DeliveryResolver.full_hierarchy(section.slug)
    node = find_node_by_title(hierarchy, title)
    
    if node && node.revision do
      {:ok, node.revision.resource_id}
    else
      {:error, "Resource '#{title}' not found in section"}
    end
  end
  
  defp get_resource_id(_section, nil) do
    {:error, "Either 'page' or 'container' must be specified"}
  end

  # Get user IDs - either specific student or all enrolled students
  defp get_user_ids(state, student_name, _section) when is_binary(student_name) do
    case Map.get(state.users, student_name) do
      nil -> 
        {:error, "Student '#{student_name}' not found"}
      user -> 
        {:ok, [user.id]}
    end
  end
  
  defp get_user_ids(_state, nil, section) do
    # Get all enrolled students in the section
    {:ok, get_enrolled_student_ids(section)}
  end

  # Get all enrolled student IDs in the section
  defp get_enrolled_student_ids(section) do
    learner_role_id = ContextRoles.get_role(:context_learner).id
    
    from(e in Sections.Enrollment,
      join: ecr in "enrollments_context_roles", on: ecr.enrollment_id == e.id,
      where: e.section_id == ^section.id,
      where: e.status == :enrolled,
      where: ecr.context_role_id == ^learner_role_id,
      select: e.user_id,
      distinct: true
    )
    |> Repo.all()
  end

  # Calculate progress using the appropriate Metrics function
  defp calculate_progress(section, resource_id, user_ids, %{page: page}) when is_binary(page) do
    # For a page, use progress_for_page
    if length(user_ids) == 1 do
      Metrics.progress_for_page(section.id, hd(user_ids), resource_id)
    else
      # For multiple users, get average progress
      progress_map = Metrics.progress_for_page(section.id, user_ids, resource_id)
      
      if map_size(progress_map) == 0 do
        0.0
      else
        total = Enum.reduce(progress_map, 0.0, fn {_user_id, progress}, acc -> acc + progress end)
        total / length(user_ids)
      end
    end
  end
  
  defp calculate_progress(section, container_id, user_ids, %{container: container}) when is_binary(container) do
    # For a container, use progress_for
    if length(user_ids) == 1 do
      Metrics.progress_for(section.id, hd(user_ids), container_id)
    else
      progress_map = Metrics.progress_for(section.id, user_ids, container_id)
      
      if map_size(progress_map) == 0 do
        0.0
      else
        # Calculate average progress across all users
        total = Enum.reduce(progress_map, 0.0, fn {_user_id, progress}, acc -> acc + progress end)
        total / length(user_ids)
      end
    end
  end

  # Find a node in the hierarchy by title
  defp find_node_by_title(%Oli.Delivery.Hierarchy.HierarchyNode{} = node, title) do
    cond do
      node.revision && node.revision.title == title ->
        node
      
      node.section_resource && node.section_resource.title == title ->
        node
      
      true ->
        Enum.find_value(node.children || [], fn child ->
          find_node_by_title(child, title)
        end)
    end
  end
  
  defp find_node_by_title(_, _), do: nil

  # Format success message
  defp format_success_message(directive, actual_progress) do
    target = directive.page || directive.container
    student_info = if directive.student, do: "Student '#{directive.student}'", else: "All students"
    
    "✓ Progress assertion passed: #{student_info} in '#{target}' has progress #{format_float(actual_progress)} (expected #{format_float(directive.progress)})"
  end

  # Format failure message  
  defp format_failure_message(directive, actual_progress) do
    target = directive.page || directive.container
    student_info = if directive.student, do: "Student '#{directive.student}'", else: "All students"
    
    "✗ Progress assertion failed: #{student_info} in '#{target}' has progress #{format_float(actual_progress)} (expected #{format_float(directive.progress)})"
  end

  # Format float for display
  defp format_float(value) when is_float(value) do
    :erlang.float_to_binary(value, [{:decimals, 3}])
  end
  
  defp format_float(value) when is_integer(value) do
    :erlang.float_to_binary(value / 1.0, [{:decimals, 3}])
  end
  
  defp format_float(value), do: to_string(value)
end