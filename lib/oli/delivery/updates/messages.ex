defmodule Oli.Delivery.Updates.Messages do
  ### Message creation API

  def message_update_progress(section_id) do
    ["update_progress", section(section_id)] |> join
  end

  ## Private helpers
  defp section(section_id), do: "section:" <> Integer.to_string(section_id)
  defp join(messages), do: Enum.join(messages, ":")
end
