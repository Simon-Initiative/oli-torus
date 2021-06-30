defmodule Oli.Activities.Model.ConditionalOutcome do
  @derive Jason.Encoder
  defstruct [:id, :conditions, :event, :name, :disabled, :default, :correct, :priority]

  def parse(outcome) when is_map(outcome) do
    {:ok,
     %Oli.Activities.Model.ConditionalOutcome{
       id: Map.get(outcome, "id"),
       event: Map.get(outcome, "event"),
       name: Map.get(outcome, "name"),
       conditions: Map.get(outcome, "conditions"),
       disabled: Map.get(outcome, "disabled", false),
       default: Map.get(outcome, "default", false),
       correct: Map.get(outcome, "correct", false),
       priority: Map.get(outcome, "priority", 1)
     }}
  end

  def parse([]), do: []

  def parse(outcomes) when is_list(outcomes) do
    Enum.map(outcomes, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(_) do
    {:error, "invalid conditional outcome"}
  end
end
