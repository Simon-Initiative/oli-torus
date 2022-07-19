defmodule Oli.Rendering.Error do
  @moduledoc """
  This modules defines the rendering functionality for a rendering error.
  """
  alias Oli.Rendering.Context

  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]

  @doc """
  Renders an Oli page given a valid page model (list of page items).
  Returns an IO list of strings.
  """
  def render(%Context{render_opts: render_opts} = context, element, error, writer) do
    if render_opts.render_errors do
      writer.error(context, element, error)
    else
      []
    end
  end
end
