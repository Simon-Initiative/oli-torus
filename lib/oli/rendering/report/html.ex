defmodule Oli.Rendering.Report.Html do
  @moduledoc """
  Implements the Html writer for content report rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Report

  def report(%Context{} = _context, next, %{"id" => id}) do
    [
      ~s|<div id="#{id}" class="survey"><div class="survey-label">Report</div><div class="content-purpose-content content">|,
      next.(),
      "</div></div>\n"
    ]
  end

  def elements(%Context{} = context, elements) do
    Elements.render(context, elements, Elements.Html)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
