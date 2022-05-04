defmodule Oli.Rendering.Elements.Html do
  @moduledoc """
  Implements the Html writer for rendering errors
  """
  @behaviour Oli.Rendering.Elements

  alias Oli.Rendering.Context
  alias Oli.Rendering.Content
  alias Oli.Rendering.Activity
  alias Oli.Rendering.Group
  alias Oli.Rendering.Break
  alias Oli.Rendering.Error

  def content(%Context{} = context, element) do
    Content.render(context, element, Content.Html)
  end

  def activity(%Context{} = context, element) do
    Activity.render(context, element, Activity.Html)
  end

  def group(%Context{} = context, element) do
    Group.render(context, element, Group.Html)
  end

  def break(%Context{} = context, element) do
    Break.render(context, element, Break.Html)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
