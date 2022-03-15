defmodule Oli.Utils.Surface do
  def encode_attr(nil), do: nil
  def encode_attr(data) when is_binary(data), do: Jason.encode!(%{type: "string", data: data})
  def encode_attr(data), do: Jason.encode!(%{type: "object", data: Jason.encode!(data)})
end
