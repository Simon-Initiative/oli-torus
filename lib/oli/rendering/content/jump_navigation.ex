defmodule Oli.Rendering.Content.JumpNavigation do
  @moduledoc false

  def activity_target_id(activity_id), do: "jump-question-#{safe_id(activity_id)}"

  def activity_target_id(activity_id, occurrence_id),
    do: "jump-question-#{safe_id(activity_id)}-#{safe_id(occurrence_id)}"

  def selection_target_id(selection_id), do: "jump-selection-#{safe_id(selection_id)}"

  def target_classes do
    "scroll-mt-[280px] target:outline target:outline-2 target:outline-offset-4 target:outline-Border-border-focus"
  end

  defp safe_id(value) do
    value
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
    |> String.trim("-")
    |> case do
      "" -> "target"
      id -> id
    end
  end
end
