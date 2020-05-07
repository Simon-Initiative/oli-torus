defmodule Oli.Activities.Model.Transformation do

  defstruct [:id, :path, :operation]

  def parse(%{"id" => id, "path" => path, "operation" => operation_str }) do

    case operation_str do
      "shuffle" ->
        {:ok, %Oli.Activities.Model.Transformation{
          id: id,
          path: path,
          operation: :shuffle
        }}
      error -> error
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
