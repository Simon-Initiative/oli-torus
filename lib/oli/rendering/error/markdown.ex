defmodule Oli.Rendering.Error.Markdown do
  @moduledoc """
  Implements the Markdown writer for rendering errors
  """
  @behaviour Oli.Rendering.Error

  alias Oli.Rendering.Context

  def error(%Context{}, _element, {_, _error_id, error_msg}) do
    [
      "---\n",
      "##### Error",
      error_msg,
      "---\n"
    ]
  end
end
