defmodule Oli.Rendering.Page do
  @moduledoc """
  This modules defines the rendering functionality for an Oli page. Rendering is
  extensibile to any format which implements the behavior defined in this module, then specifying
  that format at render time. For an example of how exactly to extend this, see `page/html.ex`.
  """
  import Oli.Utils

  alias Oli.Rendering.Context

  @callback content(%Context{}, %{}) :: [any()]
  @callback activity(%Context{}, %{}) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]

  @doc """
  Renders an Oli page given a valid page model (list of page items).
  Returns an IO list of raw html strings to be futher processed by Phoenix/BEAM writev.
  """
  def render(%Context{render_opts: render_opts} = context, page_model, writer)
      when is_list(page_model) do
    # We do not currently support groups in basic Torus pages, but using PageContent.map here
    # allows us to "read through" any groups that we might happen to encounter
    {_, output} =
      Oli.Resources.PageContent.map_reduce(%{"model" => page_model}, [], fn element, output ->
        case element do
          %{"type" => "content"} ->
            {element, output ++ writer.content(context, element)}

          %{"type" => "activity-reference"} ->
            {element, output ++ writer.activity(context, element)}

          %{"type" => "group"} ->
            {element, output}

          _ ->
            {error_id, error_msg} = log_error("Page item is not supported", element)

            if render_opts.render_errors do
              {element,
               output ++ writer.error(context, element, {:unsupported, error_id, error_msg})}
            else
              {element, output}
            end
        end
      end)

    output
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
