defmodule OliWeb.Layouts do
  use OliWeb, :html

  import OliWeb.Components.Utils
  import OliWeb.Components.Delivery.Layouts

  embed_templates "layouts/*"
end
