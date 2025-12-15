defmodule Oli.Features.Feature do
  @derive Jason.Encoder
  defstruct [
    :label,
    :description,
    enabled: false
  ]
end
