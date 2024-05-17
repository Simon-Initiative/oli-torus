defmodule Oli.Rendering.Report do
  @moduledoc """
  This modules defines the rendering functionality for report.
  """
  import Oli.Utils

  alias Oli.Rendering.Context

  @type next :: (-> String.t())

  @callback report(%Context{}, next, %{}) :: [any()]
  # @callback elements(%Context{}, []) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]

  @doc """
  Renders a report element that has children elements. Returns an IO list of strings.
  """
  def render(
        %Context{} = context,
        %{"type" => "report", "id" => id, "children" => children} = element,
        writer
      ) do
    pagination_mode = Map.get(element, "paginationMode", "normal")

    next = fn ->
      writer.elements(
        %Context{
          context
          | report_id: id,
            pagination_mode: pagination_mode,
            is_annotation_level: true
        },
        children
      )
    end

    writer.report(%Context{context | is_annotation_level: true}, next, element)
  end

  # Renders an error message if none of the signatures above match. Logging and rendering of errors
  # can be configured using the render_opts in context
  def render(%Context{render_opts: render_opts} = context, element, writer) do
    {error_id, error_msg} = log_error("Report render error", element)

    if render_opts.render_errors do
      writer.error(context, element, {:invalid, error_id, error_msg})
    else
      []
    end
  end
end
