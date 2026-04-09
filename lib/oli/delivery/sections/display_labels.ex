defmodule Oli.Delivery.Sections.DisplayLabels do
  @moduledoc """
  Shared display-oriented label helpers for delivery hierarchies.

  This module formats labels and titles from canonical or display numbering while
  keeping the underlying numbering model in the delivery layer instead of the web layer.
  """

  alias Oli.Delivery.Hierarchy.HierarchyNode
  alias Oli.Resources.Numbering
  alias Oli.Resources.ResourceType

  def effective_numbering(%HierarchyNode{display_numbering: :not_set, numbering: numbering}),
    do: numbering

  def effective_numbering(%HierarchyNode{display_numbering: nil}), do: nil

  def effective_numbering(%HierarchyNode{display_numbering: %Numbering{} = numbering}),
    do: numbering

  def effective_numbering(%HierarchyNode{numbering: numbering}), do: numbering

  def effective_numbering(%{"display_numbering" => nil}), do: nil

  def effective_numbering(%{
        "display_numbering" => %{"level" => level, "index" => index} = numbering
      }) do
    build_numbering(level, index, numbering["labels"])
  end

  def effective_numbering(%{"numbering" => %{"level" => level, "index" => index} = numbering}) do
    build_numbering(level, index, numbering["labels"])
  end

  def effective_numbering(%{"level" => level, "index" => index}) do
    build_numbering(level, index, nil)
  end

  def resource_index(%HierarchyNode{} = node, false) do
    if container?(node), do: nil, else: effective_numbering_index(node)
  end

  def resource_index(%HierarchyNode{} = node, true), do: effective_numbering_index(node)
  def resource_index(%{"type" => "container"}, false), do: nil

  def resource_index(%{} = node, _display_curriculum_item_numbering),
    do: effective_numbering_index(node)

  def resource_index(_, _display_curriculum_item_numbering), do: nil

  def resource_label(node, display_curriculum_item_numbering \\ true, customizations \\ nil)

  def resource_label(%HierarchyNode{} = node, display_curriculum_item_numbering, customizations) do
    cond do
      !container?(node) ->
        base_label = resource_type_label(node, customizations)

        case resource_index(node, display_curriculum_item_numbering) do
          nil -> base_label
          index -> "#{base_label} #{index}"
        end

      display_curriculum_item_numbering ->
        case effective_numbering(node) do
          nil ->
            nil

          _ ->
            base_label = resource_type_label(node, customizations)

            case resource_index(node, true) do
              nil -> base_label
              index -> "#{base_label} #{index}"
            end
        end

      true ->
        nil
    end
  end

  def resource_label(
        %{"type" => "page"} = node,
        _display_curriculum_item_numbering,
        _customizations
      ) do
    case resource_index(node, true) do
      nil -> "Page"
      index -> "Page #{index}"
    end
  end

  def resource_label(
        %{"type" => "container", "level" => level} = node,
        display_curriculum_item_numbering,
        customizations
      ) do
    if display_curriculum_item_numbering do
      case effective_numbering(node) do
        nil ->
          nil

        numbering ->
          numbering = %{
            numbering
            | level: parse_level(level),
              labels: normalize_labels(customizations)
          }

          base_label = Numbering.container_type_label(numbering)

          case resource_index(node, true) do
            nil -> base_label
            index -> "#{base_label} #{index}"
          end
      end
    end
  end

  def resource_title(node, display_curriculum_item_numbering \\ true, customizations \\ nil) do
    title =
      case node do
        %HierarchyNode{revision: revision} -> revision.title
        %{"title" => title} -> title
      end

    case resource_label(node, display_curriculum_item_numbering, customizations) do
      nil -> title
      label -> "#{label}: #{title}"
    end
  end

  def child_resource_title(parent_node, %{"type" => "container", "title" => title} = child_node) do
    case resource_index(parent_node, true) do
      nil ->
        title

      parent_index ->
        case resource_index(child_node, true) do
          nil -> title
          child_index -> "#{parent_index}.#{child_index} #{title}"
        end
    end
  end

  def child_resource_title(_parent_node, %{"title" => title}), do: title

  def label_for(nil, _title, true = _short_label, _customizations), do: nil
  def label_for(nil, title, false = _short_label, _customizations), do: title

  def label_for(numbering, title, short_label, customizations) do
    container_label =
      get_container_label(
        numbering.level,
        customizations || Map.from_struct(Oli.Branding.CustomLabels.default())
      )

    if short_label do
      ~s{#{container_label} #{numbering.index}}
    else
      ~s{#{container_label} #{numbering.index}: #{title}}
    end
  end

  def container?(%HierarchyNode{revision: %{resource_type_id: resource_type_id}}),
    do: ResourceType.get_type_by_id(resource_type_id) == "container"

  def container?(%{resource_type_id: resource_type_id}),
    do: ResourceType.get_type_by_id(resource_type_id) == "container"

  def container?(%{"type" => type}), do: type == "container"

  defp resource_type_label(%HierarchyNode{} = node, nil) do
    case effective_numbering(node) do
      nil -> nil
      numbering -> Numbering.container_type_label(numbering)
    end
  end

  defp resource_type_label(%HierarchyNode{} = node, customizations) do
    case effective_numbering(node) do
      nil ->
        nil

      numbering ->
        Numbering.container_type_label(%{numbering | labels: normalize_labels(customizations)})
    end
  end

  defp effective_numbering_index(%HierarchyNode{} = node) do
    case effective_numbering(node) do
      nil -> nil
      %Numbering{index: index} -> index
    end
  end

  defp effective_numbering_index(%{} = node) do
    case effective_numbering(node) do
      nil -> nil
      %Numbering{index: index} -> index
    end
  end

  defp get_container_label(numbering_level, customizations) do
    case numbering_level do
      0 -> "Curriculum"
      1 -> Map.get(customizations, :unit)
      2 -> Map.get(customizations, :module)
      _ -> Map.get(customizations, :section)
    end
  end

  defp normalize_labels(nil), do: Oli.Branding.CustomLabels.default() |> Map.from_struct()
  defp normalize_labels(labels) when is_struct(labels), do: Map.from_struct(labels)
  defp normalize_labels(labels), do: labels

  defp build_numbering(level, index, labels) do
    case parse_level(level) do
      nil ->
        nil

      parsed_level ->
        %Numbering{
          level: parsed_level,
          index: parse_optional_index(index),
          labels: normalize_labels(labels)
        }
    end
  end

  defp parse_level(level) when is_integer(level), do: level

  defp parse_level(level) when is_binary(level) do
    case Integer.parse(level) do
      {parsed_level, ""} -> parsed_level
      _ -> nil
    end
  end

  defp parse_level(_), do: nil

  defp parse_optional_index(nil), do: nil
  defp parse_optional_index(index) when is_integer(index), do: index

  defp parse_optional_index(index) when is_binary(index) do
    case Integer.parse(index) do
      {parsed_index, ""} -> parsed_index
      _ -> nil
    end
  end

  defp parse_optional_index(_), do: nil
end
