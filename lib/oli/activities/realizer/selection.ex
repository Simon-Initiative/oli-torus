defmodule Oli.Activities.Realizer.Selection do
  @derive Jason.Encoder
  @enforce_keys [:id, :count, :logic]
  defstruct [:id, :count, :logic]

  alias Oli.Activities.Realizer.Logic
  alias Oli.Activities.Realizer.Selection

  @type t() :: %__MODULE__{
          count: integer(),
          logic: %Logic{}
        }

  def parse(%{"count" => count, "id" => id, "logic" => logic}) do
    case Logic.parse(logic) do
      {:ok, logic} -> {:ok, %Selection{id: id, count: count, logic: logic}}
      e -> e
    end
  end

  def parse(_) do
    {:error, "invalid selection"}
  end
end
