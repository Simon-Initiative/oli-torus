defmodule Oli.Rendering.Alternatives.Plaintext do
  @moduledoc """
  Implements the Plaintext writer for rendering alternatives
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Alternatives

  def alternatives(%Context{} = context, model) do
    Elements.render(context, model, Elements.Plaintext)
  end

  def preference_selector(%Context{}, _model) do
    []
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Plaintext)
  end
end
