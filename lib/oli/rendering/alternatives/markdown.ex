defmodule Oli.Rendering.Alternatives.Markdown do
  @moduledoc """
  Implements the Markdown writer for rendering alternatives
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error
  alias Oli.Resources.Alternatives.Selection

  @behaviour Oli.Rendering.Alternatives

  @impl Oli.Rendering.Alternatives
  def alternative(
        %Context{} = context,
        %Selection{
          alternative: %{
            "type" => "alternative",
            "children" => children
          },
          hidden: hidden
        }
      ) do
    if hidden do
      []
    else
      Elements.render(context, children, Elements.Markdown)
    end
  end

  @impl Oli.Rendering.Alternatives
  def preference_selector(_context, _selection), do: []

  @impl Oli.Rendering.Alternatives
  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Markdown)
  end
end
