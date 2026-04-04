defmodule OliWeb.PageDeliveryView do
  use OliWeb, :view
  use Phoenix.Component

  alias Oli.Resources.ResourceType
  alias Oli.Resources.Numbering
  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias OliWeb.Router.Helpers, as: Routes
  alias Oli.Delivery.Attempts.Core
  alias OliWeb.Common.Utils

  import Oli.Utils, only: [value_or: 2]

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

  def previous_url(conn, %{"slug" => slug} = previous_page, preview_mode, section_slug) do
    Routes.page_delivery_path(conn, action(preview_mode, previous_page), section_slug, slug)
  end

  def previous_title(%{"title" => title}) do
    title
  end

  def next_url(conn) do
    url_from_desc(conn, conn.assigns.next_page)
  end

  def next_url(conn, %{"slug" => slug} = next_page, preview_mode, section_slug) do
    Routes.page_delivery_path(conn, action(preview_mode, next_page), section_slug, slug)
  end

  def next_title(%{"title" => title}) do
    title
  end

  def prev_link(assigns) do
    ~H"""
    <%= link to: @to, class: "page-nav-link btn", onclick: assigns[:onclick] do %>
      <div class="flex items-center justify-between">
        <div class="mr-4">
          <i class="fas fa-arrow-left nav-icon"></i>
        </div>
        <div class="flex flex-col text-right overflow-hidden">
          <div class="nav-label">{value_or(assigns[:label], "Previous")}</div>
          <div class="nav-title">{@title}</div>
        </div>
      </div>
    <% end %>
    """
  end

  def next_link(assigns) do
    ~H"""
    <%= link to: @to, class: "page-nav-link btn", onclick: assigns[:onclick] do %>
      <div class="flex items-center justify-between">
        <div class="flex flex-col text-left overflow-hidden">
          <div class="nav-label">{value_or(assigns[:label], "Next")}</div>
          <div class="nav-title">{@title}</div>
        </div>
        <div class="ml-4">
          <i class="fas fa-arrow-right nav-icon"></i>
        </div>
      </div>
    <% end %>
    """
  end

  def action(preview_mode, %{resource_type_id: _resource_type_id} = revision),
    do: action(preview_mode, container?(revision))

  def action(preview_mode, %{"type" => type}), do: action(preview_mode, type == "container")

  def action(preview_mode, is_container) when is_boolean(is_container) do
    case {preview_mode, is_container} do
      {true, true} ->
        :container_preview

      {true, false} ->
        :page_preview

      {false, true} ->
        :container

      {false, false} ->
        :page
    end
  end

  def container?(%HierarchyNode{revision: %{resource_type_id: resource_type_id}}),
    do: ResourceType.get_type_by_id(resource_type_id) == "container"

  def container?(%{resource_type_id: resource_type_id}),
    do: ResourceType.get_type_by_id(resource_type_id) == "container"

  def container?(%{"type" => type}), do: type == "container"

  def resource_index(_node, false), do: nil

  def resource_index(%HierarchyNode{numbering: %Numbering{index: index}}, true), do: index
  def resource_index(%{"index" => index}, true), do: index
  def resource_index(_, true), do: nil

  def resource_label(node, display_curriculum_item_numbering \\ true, customizations \\ nil)

  def resource_label(%HierarchyNode{} = node, display_curriculum_item_numbering, customizations) do
    base_label = resource_type_label(node, customizations)

    case resource_index(node, display_curriculum_item_numbering) do
      nil -> base_label
      index -> "#{base_label} #{index}"
    end
  end

  def resource_label(
        %{"type" => "page"} = node,
        display_curriculum_item_numbering,
        _customizations
      ) do
    case resource_index(node, display_curriculum_item_numbering) do
      nil -> "Page"
      index -> "Page #{index}"
    end
  end

  def resource_label(
        %{"type" => "container", "level" => level} = node,
        display_curriculum_item_numbering,
        customizations
      ) do
    numbering = %Numbering{
      level: String.to_integer(level),
      index: parse_index(node["index"]),
      labels: normalize_labels(customizations)
    }

    base_label = Numbering.container_type_label(numbering)

    case resource_index(node, display_curriculum_item_numbering) do
      nil -> base_label
      index -> "#{base_label} #{index}"
    end
  end

  def resource_title(node, display_curriculum_item_numbering \\ true, customizations \\ nil) do
    title =
      case node do
        %HierarchyNode{revision: revision} -> revision.title
        %{"title" => title} -> title
      end

    "#{resource_label(node, display_curriculum_item_numbering, customizations)}: #{title}"
  end

  def child_resource_title(
        parent_node,
        %{"type" => "container", "index" => child_index, "title" => title},
        true,
        _customizations
      ) do
    case resource_index(parent_node, true) do
      nil -> title
      parent_index -> "#{parent_index}.#{child_index} #{title}"
    end
  end

  def child_resource_title(_parent_node, %{"title" => title}, _display, _customizations),
    do: title

  def container_title(_node, display_curriculum_item_numbering \\ true)

  def container_title(%HierarchyNode{} = node, display_curriculum_item_numbering),
    do: resource_title(node, display_curriculum_item_numbering)

  def container_title(%{"type" => "container"} = node, display_curriculum_item_numbering),
    do: resource_title(node, display_curriculum_item_numbering)

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

  defp resource_type_label(%HierarchyNode{numbering: numbering}, nil),
    do: Numbering.container_type_label(numbering)

  defp resource_type_label(%HierarchyNode{numbering: numbering}, customizations) do
    Numbering.container_type_label(%{numbering | labels: normalize_labels(customizations)})
  end

  defp normalize_labels(nil), do: Oli.Branding.CustomLabels.default() |> Map.from_struct()
  defp normalize_labels(labels) when is_struct(labels), do: Map.from_struct(labels)
  defp normalize_labels(labels), do: labels

  defp parse_index(index) when is_integer(index), do: index
  defp parse_index(index) when is_binary(index), do: String.to_integer(index)

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

    resource_attempt =
      Oli.Delivery.Attempts.Core.get_resource_attempt_and_revision(
        activity_attempt.resource_attempt_id
      )

    effective_settings = Oli.Delivery.Settings.get_combined_settings(resource_attempt)

    state =
      Oli.Activities.State.ActivityState.from_attempt(
        activity_attempt,
        Map.values(part_attempts_map),
        model,
        nil,
        nil,
        effective_settings
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
end
