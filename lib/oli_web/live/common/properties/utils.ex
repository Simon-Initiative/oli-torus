defmodule OliWeb.Common.Properties.Utils do
  def boolean(b) do
    if b do
      "True"
    else
      "False"
    end
  end
end
