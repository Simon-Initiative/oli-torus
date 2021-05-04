defmodule OliWeb.PageDeliveryView do
  use OliWeb, :view

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Resources.ResourceType
  alias Oli.Resources.Numbering

  def is_instructor?(conn, section_slug) do
    user = conn.assigns.current_user
    ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_instructor))
  end

  def container?(page) do
    ResourceType.get_type_by_id(page.resource_type_id) == "container"
  end

  def container_title(hierarchy_node) do
    Numbering.prefix(hierarchy_node.numbering) <> ": " <> hierarchy_node.revision.title
  end

  def has_submitted_attempt?(resource_access) do
    case {resource_access.score, resource_access.out_of} do
      {nil, nil} ->
        # resource was accessed but no attempt was submitted
        false

      {_score, _out_of} ->
        true
    end
  end

  def encode_pages(conn, section_slug, hierarchy) do
    Oli.Utils.HierarchyNode.flatten_pages(hierarchy)
    |> Enum.map(fn revision -> Routes.page_delivery_path(conn, :page, section_slug, revision.slug) end)
    |> Jason.encode!()
    |> Base.encode64()
  end

  def encode_activity_attempts(latest_attempts) do
    Map.keys(latest_attempts)
    |> Enum.map(fn activity_id ->
      {activity_attempt, part_attempts_map} = Map.get(latest_attempts, activity_id)
      {:ok, model} = Oli.Activities.Model.parse(activity_attempt.transformed_model)
      Oli.Activities.State.ActivityState.from_attempt(activity_attempt, Map.values(part_attempts_map), model)
    end)
    |> Jason.encode!()
    |> Base.encode64()
  end

  def calculate_score_percentage(resource_access) do
    case {resource_access.score, resource_access.out_of} do
      {nil, nil} ->
        # resource was accessed but no attempt was submitted
        ""

      {score, out_of} ->
        if out_of != 0 do
          percent =
            (score / out_of * 100)
            |> round
            |> Integer.to_string()

          percent <> "%"
        else
          "0%"
        end
    end
  end
end
