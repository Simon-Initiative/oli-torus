defmodule Oli.Rendering.Survey do
  @moduledoc """
  This modules defines the rendering functionality for group.
  """
  import Oli.Utils

  alias Oli.Rendering.Context

  @type next :: (() -> String.t())

  @callback survey(%Context{}, next, %{}) :: [any()]
  @callback elements(%Context{}, []) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]

  @doc """
  Renders a survey element that has children elements. Returns an IO list of strings.
  """
  def render(
        %Context{} = context,
        %{"type" => "survey", "id" => id, "children" => children} = element,
        writer
      ) do
    next = fn -> writer.elements(%Context{context | survey_id: id}, children) end

    writer.survey(context, next, element)
  end

  # Renders an error message if none of the signatures above match. Logging and rendering of errors
  # can be configured using the render_opts in context
  def render(%Context{render_opts: render_opts} = context, element, writer) do
    {error_id, error_msg} = log_error("Survey render error", element)

    if render_opts.render_errors do
      writer.error(context, element, {:invalid, error_id, error_msg})
    else
      []
    end
  end
end
