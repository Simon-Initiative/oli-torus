defmodule Oli.Activities.Model.Explanation do
  @derive Jason.Encoder
  defstruct [:id, :content]

  def parse(%{"id" => id, "content" => content}) do
    {:ok, %Oli.Activities.Model.Explanation{id: id, content: content}}
  end

  def parse(%{"content" => _}) do
    {:error, "invalid explanation: missing id"}
  end

  def parse(_) do
    {:error, "invalid explanation"}
  end
end
