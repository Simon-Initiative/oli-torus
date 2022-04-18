defmodule Oli.Rendering.Page do
  @moduledoc """
  This modules defines the rendering functionality for an Oli page. Rendering is
  extensible to any format which implements the behavior defined in this module, then specifying
  that format at render time. For an example of how exactly to extend this, see `page/html.ex`.
  """
  import Oli.Utils

  alias Oli.Rendering.Context

  @callback content(%Context{}, %{}) :: [any()]
  @callback activity(%Context{}, %{}) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]

  @doc """
  Renders an Oli page given a valid page model (list of page items).
  Returns an IO list of raw html strings to be further processed by Phoenix/BEAM writev.
  """
  def render(%Context{render_opts: render_opts} = context, elements, writer) when is_list(elements) do
    Enum.reduce(elements, [], fn element, output ->
      case element do
        %{"type" => "content"} ->
          output ++ writer.content(context, element)

        # Activity bank selections only are rendered during an instructor preview, otherwise
        # they have already been realized into specific activity-references
        %{"type" => "selection"} ->
          output ++ writer.content(context, element)

        %{"type" => "activity-reference"} ->
          output ++ writer.activity(context, element)

        %{"type" => "group"} ->
          output ++ writer.group(context, element, writer)

        _ ->
          {error_id, error_msg} = log_error("Element type is not supported", element)

          if render_opts.render_errors do
            output ++ writer.error(context, element, {:unsupported, error_id, error_msg})
          else
            output
          end
      end
    end)
  end

  # Renders an error message if the signature above does not match. Logging and rendering of errors
  # can be configured using the render_opts in context
  def render(%Context{render_opts: render_opts} = context, page_model, writer) do
    {error_id, error_msg} = log_error("Page model is invalid", page_model)

    if render_opts.render_errors do
      writer.error(context, page_model, {:invalid_page_model, error_id, error_msg})
    else
      []
    end
  end
end
