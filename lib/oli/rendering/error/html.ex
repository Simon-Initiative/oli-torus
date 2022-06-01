defmodule Oli.Rendering.Error.Html do
  @moduledoc """
  Implements the Html writer for rendering errors
  """
  @behaviour Oli.Rendering.Error

  alias Oli.Rendering.Context

  def error(%Context{}, _element, {_, _error_id, error_msg}) do
    [
      "<div class=\"alert alert-danger\">#{error_msg}</div>\n"
    ]
  end
end
