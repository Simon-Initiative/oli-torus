defmodule Oli.Rendering.Page.Html do
  alias Oli.Rendering.Context
  alias Oli.Rendering.Content
  alias Oli.Rendering.Activity
  alias Oli.Rendering.Unsupported

  @behaviour Oli.Rendering.Page

  def content(%Context{} = context, element) do
    Content.render(context, element, Content.Html)
  end

  def activity(%Context{} = context, element) do
    Activity.render(context, element, Activity.Html)
  end

  def unsupported(%Context{} = context, element) do
    Unsupported.render(context, element, Unsupported.Html)
  end

end
