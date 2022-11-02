defmodule Oli.Rendering.Alternatives.Plaintext do
  @moduledoc """
  Implements the Plaintext writer for rendering alternatives
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
            "children" => children,
            "value" => value
          },
          hidden: hidden
        }
      ) do
    [
      ~s|[alternative value: #{value}#{maybe_hidden(hidden)}]\n|,
      Elements.render(context, children, Elements.Plaintext),
      "\n"
    ]
  end

  defp maybe_hidden(true), do: " hidden: true"
  defp maybe_hidden(false), do: ""

  @impl Oli.Rendering.Alternatives
  def preference_selector(%Context{}, _model) do
    []
  end

  @impl Oli.Rendering.Alternatives
  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Plaintext)
  end
end
