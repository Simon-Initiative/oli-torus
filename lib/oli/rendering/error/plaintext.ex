defmodule Oli.Rendering.Error.Plaintext do
  @moduledoc """
  Implements the Html writer for rendering errors
  """
  @behaviour Oli.Rendering.Error

  alias Oli.Rendering.Context

  def error(%Context{}, _element, {_, error_id, error_msg}) do
    [
      "[#{error_msg}. Please contact support with issue ##{error_id}]\n"
    ]
  end
end
