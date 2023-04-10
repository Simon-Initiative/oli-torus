defmodule OliWeb.DeliveryView do
  use OliWeb, :view
  use Phoenix.Component

  import OliWeb.Common.SourceImage

  def source_id(source) do
    case Map.get(source, :type, nil) do
      nil -> "publication:#{source.id}"
      _ -> "product:#{source.id}"
    end
  end
end
