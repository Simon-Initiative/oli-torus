defmodule Oli.Rendering.Group do
  @moduledoc """
  This modules defines the rendering functionality for content group. Rendering is
  extensible to any format which implements the behavior defined in this module, then specifying
  that format at render time. For an example of how exactly to extend this, see `group/html.ex`.
  """
  import Oli.Utils

  alias Oli.Rendering.Context
  alias Oli.Rendering.Page

  @type next :: (() -> String.t())

  @callback group(%Context{}, next, %{}) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]

  @doc """
  Renders a content group that has children elements. Returns an IO list of raw html strings to be further processed by
  Phoenix/BEAM writev.
  """
  def render(
        %Context{} = context,
        %{"type" => "group", "children" => children} = element,
        writer,
        pageWriter
      ) do
    # reset active_page_break here to 1 since we only want it to affect top-level model children and
    # groups should not contain any more than the single implicit page break
    next = fn -> Page.render(%Context{context | active_page_break: 1}, children, pageWriter) end
    writer.group(context, next, element)
  end

  # Renders an error message if none of the signatures above match. Logging and rendering of errors
  # can be configured using the render_opts in context
  def render(%Context{render_opts: render_opts} = context, element, writer) do
    {error_id, error_msg} = log_error("Group render error", element)

    if render_opts.render_errors do
      writer.error(context, element, {:invalid, error_id, error_msg})
    else
      []
    end
  end
end
