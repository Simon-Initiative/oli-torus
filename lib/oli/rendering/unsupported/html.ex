defmodule Oli.Rendering.Unsupported.Html do
  alias Oli.Rendering.Context

  require Logger

  @behaviour Oli.Rendering.Unsupported

  def unsupported(%Context{} = _context, element) do
    Logger.warn("Element is not supported: #{Kernel.inspect(element)}")

    ["<div class=\"unsupported-element\">Element is not supported. Please contact support.</div>\n"]
  end

end
