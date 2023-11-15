defmodule OliWeb.Layouts do
  use OliWeb, :html

  import OliWeb.Components.Utils

  embed_templates "layouts/*"
end
