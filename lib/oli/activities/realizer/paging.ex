defmodule Oli.Activities.Realizer.Paging do
  @derive Jason.Encoder
  @enforce_keys [:limit, :offset]
  defstruct [:limit, :offset]

  @type t() :: %__MODULE__{
          limit: integer(),
          offset: integer()
        }

  def parse(%{"limit" => limit, "offset" => offset}) do
    {:ok, %Oli.Activities.Realizer.Paging{limit: limit, offset: offset}}
  end
end
