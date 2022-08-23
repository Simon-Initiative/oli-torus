defmodule Oli.Features.Feature do
  @derive Jason.Encoder
  defstruct [
    :id,
    :label,
    :description
  ]
end
