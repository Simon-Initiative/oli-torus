defmodule Oli.Activities.Model.Trigger do
  @derive Jason.Encoder
  defstruct [:id, :type, :prompt, :id_ref]

  def parse(%{"id" => id, "type" => type, "prompt" => prompt, "id_ref" => id_ref}) do
    {:ok, %Oli.Activities.Model.Trigger{id: id, type: type, prompt: prompt, id_ref: id_ref}}
  end

  def parse(triggers) when is_list(triggers) do
    Enum.map(triggers, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(_) do
    {:error, "invalid trigger"}
  end
end
