defmodule Oli.Activities.Reports.Providers.OliLikert do
  @behaviour Oli.Activities.Reports.Renderer

  alias Oli.Rendering.Context

  @impl Oli.Activities.Reports.Renderer
  def render(%Oli.Rendering.Context{}, %{"activityId" => activity_id} = element) do
    data = [["Apples", 10], ["Bananas", 12], ["Pears", 2]]

    output =
      data
      |> Contex.Dataset.new()
      |> Contex.Plot.new(Contex.BarChart, 600, 400)
      |> Contex.Plot.to_svg()

     {:ok, elem(output, 1)}
  end

end
