defmodule Oli.Activities.Model.Transformation do
  defstruct [:id, :path, :operation, :data, :first_attempt_only]

  def parse(%{"operation" => operation_str} = json) do
    id = Map.get(json, "id", UUID.uuid4())

    case operation_str do
      "shuffle" ->
        {:ok,
         %Oli.Activities.Model.Transformation{
           data: nil,
           id: id,
           path: Map.get(json, "path"),
           first_attempt_only: Map.get(json, "firstAttemptOnly", true),
           operation: :shuffle
         }}

      "variable_substitution" ->
        {:ok,
         %Oli.Activities.Model.Transformation{
           data: Map.get(json, "data"),
           id: id,
           path: nil,
           first_attempt_only: Map.get(json, "firstAttemptOnly", false),
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
