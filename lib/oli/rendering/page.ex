defmodule Oli.Rendering.Page do
  @moduledoc """
  This modules defines the rendering functionality for an Oli page. Rendering is
  extensible to any format which implements the behavior defined in this module, then specifying
  that format at render time. For an example of how exactly to extend this, see `page/html.ex`.
  """
  import Oli.Utils

  alias Oli.Rendering.Context

  @callback page(%Context{}, %{}) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]

  @doc """
  Renders an Oli page given a valid page model (list of page items).
  Returns an IO list of strings.
  """
  def render(context, %{"model" => model}, writer) when is_list(model) do
    writer.page(context, model)
  end

  # Renders an error message if the signature above does not match. Logging and rendering of errors
  # can be configured using the render_opts in context
  def render(%Context{render_opts: render_opts} = context, page_content, writer) do
    {error_id, error_msg} = log_error("Page is invalid", page_content)

    if render_opts.render_errors do
      writer.error(context, page_content, {:invalid_page, error_id, error_msg})
    else
      []
    end
  end
end
