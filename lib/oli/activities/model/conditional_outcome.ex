defmodule Oli.Activities.Model.ConditionalOutcome do
  defstruct [:id, :rule, :actions]

  def parse(%{"id" => id, "rule" => rule, "actions" => actions}) do
    IO.inspect(actions)

    case Enum.map(actions, &parse_action/1)
         |> Oli.Activities.ParseUtils.items_or_errors() do
      {:ok, parsed_actions} ->
        {:ok,
         %Oli.Activities.Model.ConditionalOutcome{
           id: id,
           rule: rule,
           actions: parsed_actions
         }}

      {:error, _} ->
        {:error, "invalid action definition in outcome #{id}"}
    end
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
