defmodule OliWeb.PageDeliveryView do
  use OliWeb, :view

  alias Oli.Resources.ResourceType
  alias Oli.Resources.Numbering
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Attempts.Core

  def show_score(nil, nil), do: ""

  def show_score(score, out_of) do
    cond do
      out_of <= 0.0 ->
        "0"

      true ->
        (score / out_of * 100)
        |> round
        |> Integer.to_string()
    end
  end

  defp url_from_desc(conn, %{"type" => "container", "slug" => slug}),
    do: conn.assigns.container_link_url.(slug)

  defp url_from_desc(conn, %{"type" => "page", "slug" => slug}),
    do: conn.assigns.page_link_url.(slug)

  def previous_url(conn) do
    url_from_desc(conn, conn.assigns.previous_page)
  end

  def next_url(conn) do
    url_from_desc(conn, conn.assigns.next_page)
  end

  def container?(rev) do
    ResourceType.get_type_by_id(rev.resource_type_id) == "container"
  end

  def container_title(%HierarchyNode{
        numbering: %Numbering{
          level: level,
          index: index
        },
        revision: revision
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
    Oli.Delivery.Hierarchy.flatten_pages(hierarchy)
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
      encode_attempt(registered_activity_slug_map, Map.get(latest_attempts, activity_id))
    end)
    |> Enum.filter(fn data -> !is_nil(data) end)
    |> Jason.encode!()
    |> Base.encode64()
  end

  # We only encode activity attempts for basic pages, when a full attempt hiearchy is present here as
  # the second argument. These entries will be in the shape
  # of two element tuples.
  defp encode_attempt(registered_activity_slug_map, {activity_attempt, part_attempts_map}) do
    {:ok, model} = Core.select_model(activity_attempt) |> Oli.Activities.Model.parse()

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
        Core.select_model(activity_attempt)
      )
    )
  end

  # The thin attempt hierarchy will be present when the rendered page is an adaptive page. This is simply a map
  # (and doesn't match the shape above). We do not support exercising of adaptive pages from the load
  # testing framework.  Therefore, we return nil, which will be filtered out and ultimately the
  # __ACTIVITY_ATTEMPT__ load testing page variable will be an empty list.
  defp encode_attempt(_, _) do
    nil
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

  def base_resource_link_class(), do: ""
  def resource_link_class(_active = true), do: base_resource_link_class() <> " active"
  def resource_link_class(_active = false), do: base_resource_link_class()
end
