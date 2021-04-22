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

end
