defmodule Oli.Rendering.Activity.Common do
  def maybe_group_id(nil), do: ""
  def maybe_group_id(group_id), do: ~s| group_id="#{group_id}"|

  def maybe_survey_id(nil), do: ""
  def maybe_survey_id(survey_id), do: ~s| survey_id="#{survey_id}"|
end
