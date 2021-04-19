defmodule Oli.Activities.Model.ConditionalOutcome do
  defstruct [:id, :conditions, :event, :name]

  def parse(%{"id" => id}) do
    {:ok, %Oli.Activities.Model.ConditionalOutcome{id: id}}
  end

  def parse(outcomes) when is_list(outcomes) do
    Enum.map(outcomes, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(_) do
    {:error, "invalid conditional outcome"}
  end

  defp parse_action(%{"type" => "FeedbackActionDesc"} = action),
    do: Oli.Activities.Model.FeedbackAction.parse(action)

  defp parse_action(%{"type" => "NavigationActionDesc"} = action),
    do: Oli.Activities.Model.NavigationAction.parse(action)

  defp parse_action(%{"type" => "StateUpdateActionDesc"} = action),
    do: Oli.Activities.Model.StateUpdateAction.parse(action)
end
