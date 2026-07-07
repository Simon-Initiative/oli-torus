defmodule Oli.Scenarios.DirectiveValidator do
  @moduledoc """
  Validates directive attributes to ensure no unknown attributes are present.
  This helps catch typos and incorrect attribute usage in scenario YAML files.
  """

  @doc """
  Validates that only allowed attributes are present in the given data.

  ## Parameters
    - allowed_attrs: List of allowed attribute names (as strings)
    - data: Map of provided attributes from YAML
    - directive_name: Name of the directive for error reporting

  ## Returns
    - :ok if all attributes are valid
    - {:error, message} if unknown attributes are found
  """
  def validate_attributes(allowed_attrs, data, directive_name)
      when is_list(allowed_attrs) and is_map(data) and is_binary(directive_name) do
    provided_attrs = Map.keys(data)
    unknown_attrs = provided_attrs -- allowed_attrs

    case unknown_attrs do
      [] ->
        :ok

      unknown ->
        # Sort for consistent error messages
        unknown_sorted = Enum.sort(unknown)
        allowed_sorted = Enum.sort(allowed_attrs)

        {:error,
         "Unknown attributes in '#{directive_name}' directive: #{inspect(unknown_sorted)}. " <>
           "Allowed attributes are: #{inspect(allowed_sorted)}"}
    end
  end

  @doc """
  Validates attributes for nested structures like nodes in project trees.
  Similar to validate_attributes but for nested data structures.
  """
  def validate_node_attributes(data) when is_map(data) do
    cond do
      Map.has_key?(data, "page") ->
        # Page nodes should only have "page" key
        validate_attributes(["page"], data, "page node")

      Map.has_key?(data, "container") ->
        # Container nodes can have "container" and optionally "children"
        validate_attributes(["container", "children"], data, "container node")

      Map.has_key?(data, "root") ->
        # Root wrapper
        :ok

      Map.has_key?(data, "children") ->
        # Just children without container name (treated as root)
        validate_attributes(["children"], data, "root node")

      true ->
        {:error, "Invalid node structure. Expected 'page', 'container', or 'children' key."}
    end
  end

  @doc """
  Validates assertion sub-structures.
  """
  def validate_assertion_attributes(type, data) when is_map(data) do
    allowed_attrs =
      case type do
        :structure ->
          ["to", "root"]

        :resource ->
          ["to", "target", "resource"]

        :progress ->
          ["section", "progress", "page", "container", "student"]

        :proficiency ->
          ["section", "objective", "bucket", "value", "student", "page", "container"]

        :certificate ->
          [
            "section",
            "student",
            "enabled",
            "state",
            "with_distinction",
            "progress",
            "requires_instructor_approval",
            "required_discussion_posts",
            "required_class_notes",
            "min_percentage_for_completion",
            "min_percentage_for_distinction",
            "assessments_apply_to",
            "scored_pages",
            "title",
            "description",
            "admin_name1",
            "admin_title1",
            "admin_name2",
            "admin_title2",
            "admin_name3",
            "admin_title3"
          ]

        :discussion ->
          [
            "section",
            "post",
            "student",
            "visible",
            "status",
            "contains_discussions",
            "auto_accept",
            "anonymous_posting"
          ]

        :gating ->
          [
            "gate",
            "section",
            "student",
            "resource",
            "target",
            "source",
            "type",
            "accessible",
            "blocking_types",
            "blocking_count",
            "minimum_percentage",
            "start",
            "end"
          ]

        :prologue ->
          [
            "section",
            "student",
            "page",
            "allow_attempt",
            "show_blocking_gates",
            "attempt_message",
            "attempts_taken",
            "max_attempts",
            "attempts_summary",
            "next_attempt_ordinal",
            "terms"
          ]

        :gradebook ->
          [
            "instructor",
            "section",
            "student",
            "page",
            "score",
            "out_of",
            "was_late"
          ]

        :review_attempt ->
          [
            "section",
            "student",
            "page",
            "allow_review",
            "activities_visible",
            "answers_visible",
            "feedback_visible",
            "scores_visible",
            "activity_count"
          ]

        :activity_attempt ->
          [
            "section",
            "student",
            "page",
            "activity_virtual_id",
            "part_id",
            "activity_lifecycle_state",
            "part_lifecycle_state",
            "score",
            "out_of",
            "part_score",
            "part_out_of",
            "response",
            "answerable",
            "exists"
          ]

        :activity_customization ->
          [
            "section",
            "page",
            "embedded_activities",
            "bank_selections",
            "bank_candidates"
          ]

        :page_objectives ->
          ["section", "page", "expected"]

        :activity_objectives ->
          ["project", "activity_virtual_id", "expected"]

        :instructor_dashboard_summary ->
          [
            "section",
            "scope",
            "tolerance",
            "metrics",
            "total_students",
            "scope_label",
            "course_title",
            "cards",
            "available_slots",
            "missing_slots"
          ]

        :instructor_dashboard_progress ->
          [
            "section",
            "scope",
            "tolerance",
            "axis_label",
            "class_size",
            "completion_threshold",
            "y_axis_mode",
            "items",
            "series",
            "series_all",
            "empty_state"
          ]

        :instructor_dashboard_student_support ->
          [
            "section",
            "scope",
            "tolerance",
            "totals",
            "buckets",
            "default_bucket_id",
            "has_activity_data",
            "has_activity_data?",
            "bucket_priority"
          ]

        :instructor_dashboard_challenging_objectives ->
          [
            "section",
            "scope",
            "tolerance",
            "state",
            "has_objectives",
            "row_count",
            "rows",
            "rows_by_title",
            "scope_label",
            "course_title"
          ]

        :instructor_dashboard_assessments ->
          [
            "section",
            "scope",
            "tolerance",
            "total_rows",
            "has_assessments",
            "has_assessments?",
            "rows",
            "rows_by_title"
          ]

        _ ->
          []
      end

    validate_attributes(allowed_attrs, data, "#{type} assertion")
  end

  @doc """
  Validates objective format.
  Objectives can be either:
  - A string (simple objective)
  - A map with single key-value pair where value is a list of children
  """
  def validate_objective(objective) when is_binary(objective), do: :ok

  def validate_objective(objective) when is_map(objective) do
    case Map.to_list(objective) do
      [{title, children}] when is_binary(title) and is_list(children) ->
        :ok

      [{_, _}] ->
        {:error, "Invalid objective format. Expected {\"Title\": [children]}"}

      _ ->
        {:error, "Invalid objective format. Objective map must have exactly one key-value pair"}
    end
  end

  def validate_objective(_), do: {:error, "Invalid objective format. Must be string or map"}
end
