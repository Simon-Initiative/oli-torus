defmodule Oli.Rendering.Unsupported.Html do
  alias Oli.Rendering.Context

  require Logger

  @behaviour Oli.Rendering.Unsupported

  def unsupported(%Context{} = _context, _element) do
    ["<div class=\"unsupported-element\">Element is not supported. Please contact support.</div>\n"]
  end

end
