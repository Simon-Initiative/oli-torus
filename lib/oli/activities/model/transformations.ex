defmodule Oli.Activities.Model.Transformation do
  defstruct [:id, :path, :operation, :data]

  def parse(%{"id" => id, "operation" => operation_str} = json) do
    case operation_str do
      "shuffle" ->
        {:ok,
         %Oli.Activities.Model.Transformation{
           data: nil,
           id: id,
           path: Map.get(json, "path"),
           operation: :shuffle
         }}

      "variable_substitution" ->
        {:ok,
         %Oli.Activities.Model.Transformation{
           data: Map.get(json, "data"),
           id: id,
           path: nil,
           operation: :variable_substitution
         }}

      _ ->
        {:error, "invalid operation"}
    end
  end

  def parse(transformations) when is_list(transformations) do
    Enum.map(transformations, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(_) do
    {:error, "invalid transformation"}
  end
end
