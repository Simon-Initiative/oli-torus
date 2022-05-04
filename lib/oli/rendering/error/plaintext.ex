defmodule Oli.Rendering.Error.Plaintext do
  @moduledoc """
  Implements the Html writer for rendering errors
  """
  @behaviour Oli.Rendering.Error

  alias Oli.Rendering.Context

  def error(%Context{}, _element, {_, _error_id, error_msg}) do
    [
      "[#{error_msg}]\n"
    ]
  end
end
