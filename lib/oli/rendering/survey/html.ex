defmodule Oli.Rendering.Survey.Html do
  @moduledoc """
  Implements the Html writer for content survey rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Elements
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Survey

  def survey(
        %Context{submitted_surveys: submitted_surveys, resettable_surveys: resettable_surveys} =
          context,
        next,
        %{"id" => id}
      ) do
    {:safe, survey_controls} =
      OliWeb.Common.React.component(
        context,
        "Components.SurveyControls",
        %{
          id: id,
          isSubmitted: submitted_surveys[id],
          canReset: resettable_surveys[id]
        },
        id: "survey-controls-#{id}"
      )

    [
      ~s|<div id="#{id}" class="survey"><div class="survey-label">Survey</div><div class="survey-content">|,
      next.(),
      "</div>\n",
      survey_controls,
      "</div>\n"
    ]
  end

  def elements(%Context{} = context, elements) do
    Elements.render(context, elements, Elements.Html)
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Html)
  end
end
