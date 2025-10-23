defmodule OliWeb.DeliveryView do
  use OliWeb, :view
  use Phoenix.Component

  import OliWeb.Common.SourceImage
  import OliWeb.Components.Utils, only: [user_is_guest?: 1]

  def source_id(source) do
    case Map.get(source, :type, nil) do
      nil -> "publication:#{source.id}"
      _ -> "product:#{source.id}"
    end
  end
end
