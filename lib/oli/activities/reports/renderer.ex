defmodule Oli.Activities.Reports.Renderer do
  alias Oli.Rendering.Context

  @callback render(%Context{}, %{}) :: {:ok, term} | {:error, String.t()}

  @callback report_data(String.t(), String.t(), String.t()) :: {:ok, term} | {:error, String.t()}

  def render(implementation, %Context{} = context, element) do
    implementation.render(context, element)
  end

  def report_data(implementation, section_id, user_id, activity_id) do
    implementation.report_data(section_id, user_id, activity_id)
  end
end
