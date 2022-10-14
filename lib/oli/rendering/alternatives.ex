defmodule Oli.Rendering.Alternatives do
  @moduledoc """
  This modules defines the rendering functionality for alternatives.
  """
  import Oli.Utils

  alias Oli.Rendering.Context
  alias Oli.Resources.Alternatives.AlternativesStrategyContext

  @callback alternatives(%Context{}, %{}) :: [any()]
  @callback error(%Context{}, %{}, {Atom.t(), String.t(), String.t()}) :: [any()]

  @doc """
  Renders alternatives based on the strategy specified. The content of the
  selected alternative(s) will be rendered.

  If more than one alternative is selected, the content of all selected alternatives
  will be concatenated as a single collection of rendered elements.
  """
  def render(
        %Context{
          user: user,
          section_slug: section_slug,
          alternatives_selector_fn: alternatives_selector_fn
        } = context,
        %{"type" => "alternatives"} = element,
        writer
      ) do
    alternatives_selector_fn.(
      %AlternativesStrategyContext{user: user, section_slug: section_slug},
      element
    )
    |> Enum.flat_map(fn %{
                          "type" => "alternative",
                          "children" => children
                        } ->
      writer.alternatives(
        %Context{context | pagination_mode: "normal"},
        children
      )
    end)
  end

  # Renders an error message if none of the signatures above match. Logging and rendering of errors
  # can be configured using the render_opts in context
  def render(%Context{render_opts: render_opts} = context, element, writer) do
    {error_id, error_msg} = log_error("Alternatives render error", element)

    if render_opts.render_errors do
      writer.error(context, element, {:invalid, error_id, error_msg})
    else
      []
    end
  end
end
