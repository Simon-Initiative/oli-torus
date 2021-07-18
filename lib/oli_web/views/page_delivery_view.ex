defmodule OliWeb.PageDeliveryView do
  use OliWeb, :view

  alias Lti_1p3.Tool.ContextRoles
  alias Oli.Resources.ResourceType
  alias Oli.Resources.Numbering
  alias Oli.Publishing.HierarchyNode

  def is_instructor?(conn, section_slug) do
    user = conn.assigns.current_user
    ContextRoles.has_role?(user, section_slug, ContextRoles.get_role(:context_instructor))
  end

  def container?(rev) do
    ResourceType.get_type_by_id(rev.resource_type_id) == "container"
  end

  def container_title(%HierarchyNode{
        numbering: %Numbering{
          level: level,
          index: index,
          revision: revision
        }
      }) do
    Numbering.container_type(level) <> " #{index}: #{revision.title}"
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
    Oli.Publishing.HierarchyNode.flatten_pages(hierarchy)
    |> Enum.map(fn %{revision: revision} ->
      %{
        slug: revision.slug,
        url: Routes.page_delivery_path(conn, :page, section_slug, revision.slug),
        graded: revision.graded
      }
    end)
    |> Jason.encode!()
    |> Base.encode64()
  end

  def encode_url(url) do
    Jason.encode!(%{"url" => url})
    |> Base.encode64()
  end

  def encode_activity_attempts(registered_activity_slug_map, latest_attempts) do
    Map.keys(latest_attempts)
    |> Enum.map(fn activity_id ->
      {activity_attempt, part_attempts_map} = Map.get(latest_attempts, activity_id)
      {:ok, model} = Oli.Activities.Model.parse(activity_attempt.transformed_model)

      state =
        Oli.Activities.State.ActivityState.from_attempt(
          activity_attempt,
          Map.values(part_attempts_map),
          model
        )

      activity_type_slug =
        Map.get(registered_activity_slug_map, activity_attempt.revision.activity_type_id)

      state
      |> Map.from_struct()
      |> Map.put(
        :answers,
        Oli.Utils.LoadTesting.provide_answers(
          activity_type_slug,
          activity_attempt.transformed_model
        )
      )
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
