defmodule Oli.Grading.LineItem do


  @derive Jason.Encoder
  @enforce_keys [:scoreMaximum, :label, :resourceId]
  defstruct [:id, :scoreMaximum, :label, :resourceId]

  @type t() :: %__MODULE__{
    id: String.t(),
    scoreMaximum: float,
    label: String.t(),
    resourceId: String.t()
  }

  @oli_prefix "oli-torus-"


  def is_oli?(%__MODULE__{} = line_item) do
    case line_item.resourceId do
      @oli_prefix <> _ -> true
      _ -> false
    end
  end

  def parse_resource_id(%__MODULE__{} = line_item) do
    case line_item.resourceId do
      @oli_prefix <> resource_id -> resource_id
      _ -> nil
    end
  end

  def to_resource_id(resource_id) do
    @oli_prefix <> Integer.to_string(resource_id)
  end

end
