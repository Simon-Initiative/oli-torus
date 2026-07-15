defmodule Oli.Rendering.Activity.PreviewCustomization do
  @moduledoc false

  @copy %{
    "remove" => "Remove",
    "removed" => "Removed",
    "restore" => "Restore",
    "pending" => "Updating...",
    "pendingAnnouncement" => "Updating activity customization."
  }

  def copy, do: @copy

  def action(kind, opts \\ []) when kind in ["remove", "restore"] do
    %{kind: kind, label: Map.fetch!(@copy, kind)}
    |> maybe_disable(Keyword.get(opts, :disabled))
  end

  def removed_status_pill,
    do: %{kind: "removed", label: Map.fetch!(@copy, "removed")}

  defp maybe_disable(action, disabled) when is_boolean(disabled),
    do: Map.put(action, :disabled, disabled)

  defp maybe_disable(action, _disabled), do: action
end
