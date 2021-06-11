defmodule Oli.Activities.Model.ConditionalOutcome do
  @derive Jason.Encoder
  defstruct [:id, :conditions, :event, :name]

  def parse(%{"id" => id, "event" => event, "name" => name, "conditions" => conditions}) do
    {:ok,
     %Oli.Activities.Model.ConditionalOutcome{
       id: id,
       event: event,
       name: name,
       conditions: conditions
     }}
  end

  def parse(outcomes) when is_list(outcomes) do
    Enum.map(outcomes, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(_) do
    {:error, "invalid conditional outcome"}
  end
end
