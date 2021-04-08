defmodule Oli.Activities.Model.Feedback do
  @derive Jason.Encoder
  defstruct [:id, :content]

  def parse(%{"id" => id, "content" => content}) do
    {:ok, %Oli.Activities.Model.Feedback{id: id, content: content}}
  end

  def parse(%{"content" => _}) do
    {:error, "invalid feedback: missing id"}
  end

  def parse(_) do
    {:error, "invalid feedback"}
  end
end
