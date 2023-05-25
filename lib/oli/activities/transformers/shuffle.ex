defmodule Oli.Activities.Transformers.Shuffle do
  alias Oli.Activities.Model.Transformation
  alias Oli.Activities.Transformers.Transformer

  @behaviour Transformer

  @impl Transformer
  def transform(model, %Transformation{path: path} = transformation, _context) do
    case Map.get(model, path) do
      nil ->
        {:error, :path_not_found}

      collection ->
        model =
          case {transformation, model} do
            # if this transformation is scoped to a specific part, shuffle the part choiceIds
            {%Transformation{part_id: part_id}, %{"inputs" => inputs}}
            when not is_nil(part_id) and is_list(inputs) ->
              inputs =
                inputs
                |> Enum.map(fn input ->
                  # find the specific input that matches the part_id and shuffle its choiceIds
                  if input["partId"] == part_id,
                    do: Map.put(input, "choiceIds", Enum.shuffle(input["choiceIds"])),
                    else: input
                end)

              Map.put(model, "inputs", inputs)

            # otherwise just return the model
            _ ->
              model
          end

        {:ok, Map.put(model, path, Enum.shuffle(collection))}
    end
  end

  @impl Transformer
  def provide_batch_context(transformers) do
    {:ok, Enum.map(transformers, fn _ -> %{} end)}
  end
end
