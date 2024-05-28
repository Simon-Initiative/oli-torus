defmodule Oli.Rendering.Report.Html do
  @moduledoc """
  Implements the Html writer for content report rendering
  """

  alias Oli.Rendering.Context
  # alias Oli.Rendering.Elements
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Report

  def report(%Context{} = context, %{"id" => id} = element) do

    IO.inspect(context)
    report_provider = Module.concat([Oli, Activities, Reports, Providers, OliLikert])

    report =
      case Oli.Activities.Reports.Renderer.render(report_provider, context, element) do
        {:ok, report} -> report
        _ -> "Report not ready"
      end

    [
      ~s|<div id="#{id}" class="survey"><div class="survey-label">Report</div><div class="content-purpose-content content">|,
      report,
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
