defmodule Oli.Rendering.Report.Plaintext do
  @moduledoc """
  Implements the Plaintext writer for content survey rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Report

  def report(%Context{} = _context, %{"id" => id}) do
    [
      "[Activity Report #{id}          ]",
      "------------------------------------------\n"
    ]
  end


  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Plaintext)
  end
end
