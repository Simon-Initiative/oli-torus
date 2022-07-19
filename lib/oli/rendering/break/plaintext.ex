defmodule Oli.Rendering.Break.Plaintext do
  @moduledoc """
  Implements the Plaintext writer for break element.
  """
  alias Oli.Rendering.Context
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Break

  def break(%Context{}, _) do
    ["------------\n"]
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Plaintext)
  end
end
