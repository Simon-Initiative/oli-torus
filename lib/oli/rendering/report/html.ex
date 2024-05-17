defmodule Oli.Rendering.Report.Html do
  @moduledoc """
  Implements the Html writer for content report rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Report

  def report(%Context{} = _context, _next, %{"id" => id}) do
    data = [["Apples", 10], ["Bananas", 12], ["Pears", 2]]

    output =
      data
      |> Contex.Dataset.new()
      |> Contex.Plot.new(Contex.BarChart, 600, 400)
      |> Contex.Plot.to_svg()

    output = elem(output, 1)
    
    [
      ~s|<div id="#{id}" class="survey"><div class="survey-label">Report</div><div class="content-purpose-content content">|,
      output,
      "</div></div>\n"
    ]
  end

  # def elements(%Context{} = context, elements) do
  #   Elements.render(context, elements, Elements.Html)
  # end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
