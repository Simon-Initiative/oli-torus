defmodule Oli.Activities.Realizer.Query.Paging do
  @moduledoc """
  Paging options for activity viewing and querying.
  """

  @derive Jason.Encoder
  @enforce_keys [:limit, :offset]
  defstruct [:limit, :offset]

  @type t() :: %__MODULE__{
          limit: integer(),
          offset: integer()
        }

  def parse(%{"limit" => limit, "offset" => offset}) do
    {:ok, %Oli.Activities.Realizer.Query.Paging{limit: limit, offset: offset}}
  end
end
