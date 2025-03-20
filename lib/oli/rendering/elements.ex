defmodule Oli.Rendering.Elements do
  @moduledoc """
  This modules defines the rendering functionality for a list of block elements. Rendering is
  extensible to any format which implements the behavior defined in this module, then specifying
  that format at render time. For an example of how exactly to extend this, see `page/html.ex`.
  """
  import Oli.Utils

  alias Oli.Rendering.Context

  @callback content(%Context{}, %{}) :: [any()]
  @callback activity(%Context{}, %{}) :: [any()]
  @callback group(%Context{}, %{}) :: [any()]
  @callback survey(%Context{}, %{}) :: [any()]
  @callback report(%Context{}, %{}) :: [any()]
  @callback alternatives(%Context{}, %{}) :: [any()]
  @callback break(%Context{}, %{}) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]
  @callback paginate(%Context{}, {[], Integer.t()}) :: [any()]

  @doc """
  Renders an Oli page given a valid page model (list of page items).
  Returns an IO list of strings.
  """
  def render(
        %Context{} = context,
        elements,
        writer
      )
      when is_list(elements) do
    Enum.reduce(elements, {[], 0}, fn element, {output, br_count} ->
      case element do
        %{"type" => "content"} ->
          {output ++ writer.content(context, element), br_count}

        # Activity bank selections only are rendered during an instructor preview, otherwise
        # they have already been realized into specific activity-references
        %{"type" => "selection"} ->
          {output ++ writer.content(context, element), br_count}

        %{"type" => "activity-reference"} ->
          {output ++ writer.activity(context, element), br_count}

        %{"type" => "group"} ->
          {output ++ writer.group(context, element), br_count}

        %{"type" => "survey"} ->
          {output ++ writer.survey(context, element), br_count}

        %{"type" => "report"} ->
          {output ++ writer.report(context, element), br_count}

        %{"type" => "alternatives"} ->
          {output ++ writer.alternatives(context, element), br_count}

        %{"type" => "break"} ->
          {output ++ writer.break(context, element), br_count + 1}

        %{"type" => "lti-external-tool"} ->
          {output ++ writer.lti_external_tool(context, element), br_count}

        _ ->
          {error_id, error_msg} =
            log_error("Element type '#{element["type"]}' is not supported", element)

          {output ++
             writer.error(context, element, {:unsupported, error_id, error_msg}), br_count}
      end
    end)
    |> then(fn rendered -> writer.paginate(context, rendered) end)
  end

  # Renders an error message if the signature above does not match. Logging and rendering of errors
  # can be configured using the render_opts in context
  def render(%Context{} = context, elements, writer) do
    {error_id, error_msg} = log_error("Element content is invalid", elements)

    writer.error(context, elements, {:invalid, error_id, error_msg})
  end
end
