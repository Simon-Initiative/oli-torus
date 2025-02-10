defmodule Oli.Activities.Model.Trigger do
  @derive Jason.Encoder
  defstruct [:id, :trigger_type, :prompt, :ref_id]

  def parse(%{"id" => id, "trigger_type" => type, "prompt" => prompt} = t) do

    ref_id = Map.get(t, "ref_id", nil)
    {:ok, %Oli.Activities.Model.Trigger{id: id, trigger_type: String.to_existing_atom(type), prompt: prompt, ref_id: ref_id}}
  end

  def parse(% Oli.Activities.Model.Trigger{id: _id} = t) do
    {:ok, t}
  end

  def parse(triggers) when is_list(triggers) do
    Enum.map(triggers, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(_) do
    {:error, "invalid trigger"}
  end
end
