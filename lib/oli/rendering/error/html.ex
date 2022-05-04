defmodule Oli.Rendering.Error.Html do
  @moduledoc """
  Implements the Html writer for rendering errors
  """
  @behaviour Oli.Rendering.Error

  alias Oli.Rendering.Context

  def error(%Context{}, _element, {_, error_id, error_msg}) do
    [
      "<div class=\"alert alert-danger\">#{error_msg}. Please contact support with issue ##{error_id}</div>\n"
    ]
  end
end
