defmodule Oli.Activities.Model.Trigger do
  @derive Jason.Encoder
  defstruct [:id, :type, :prompt, :ref_id]

  def parse(%{"id" => id, "trigger_type" => type, "prompt" => prompt, "ref_id" => id_ref}) do
    {:ok, %Oli.Activities.Model.Trigger{id: id, type: type, prompt: prompt, ref_id: id_ref}}
  end

  def parse(triggers) when is_list(triggers) do
    Enum.map(triggers, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(s) do
    {:error, "invalid trigger"}
  end
end
