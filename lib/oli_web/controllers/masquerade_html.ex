defmodule OliWeb.MasqueradeHTML do
  use OliWeb, :html

  alias OliWeb.Components.Delivery.Utils

  embed_templates "masquerade_html/*"
end
