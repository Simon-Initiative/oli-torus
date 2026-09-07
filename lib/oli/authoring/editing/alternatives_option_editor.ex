defmodule Oli.Authoring.Editing.AlternativesOptionEditor do
  @moduledoc """
  Applies stable option reordering and persists a new alternatives revision.
  """

  alias Oli.Authoring.Editing.ResourceEditor
  alias Oli.Resources.Alternatives.OptionOrder

  @spec move_to(
          String.t(),
          struct(),
          [map()],
          integer() | String.t(),
          String.t(),
          integer() | String.t()
        ) ::
          {:ok, [map()], map()} | {:ok, :unchanged} | {:error, term()}
  def move_to(project_slug, author, groups, resource_id, option_id, drop_index) do
    with {:ok, resource_id} <- parse_integer(resource_id, 1),
         {:ok, drop_index} <- parse_integer(drop_index, 0),
         {:ok, group} <- find_group(groups, resource_id),
         {:ok, reordered_options} <-
           OptionOrder.move_to(group.content["options"], option_id, drop_index) do
      case reordered_options do
        :unchanged -> {:ok, :unchanged}
        reordered_options -> persist(project_slug, author, groups, group, reordered_options)
      end
    end
  end

  defp persist(project_slug, author, groups, group, reordered_options) do
    content = Map.put(group.content, "options", reordered_options)

    case ResourceEditor.edit(project_slug, group.resource_id, author, %{content: content}) do
      {:ok, updated_group} ->
        updated_groups =
          Enum.map(groups, fn existing_group ->
            if existing_group.resource_id == updated_group.resource_id,
              do: updated_group,
              else: existing_group
          end)

        {:ok, updated_groups, updated_group}

      error ->
        error
    end
  end

  defp find_group(groups, resource_id) do
    case Enum.find(groups, &(&1.resource_id == resource_id)) do
      nil -> {:error, :not_found}
      group -> {:ok, group}
    end
  end

  defp parse_integer(value, minimum) when is_integer(value) and value >= minimum,
    do: {:ok, value}

  defp parse_integer(value, minimum) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer >= minimum -> {:ok, integer}
      _ -> {:error, :invalid_integer}
    end
  end

  defp parse_integer(_value, _minimum), do: {:error, :invalid_integer}
end
