defmodule Oli.Activities.Model.Feedback do
  import Oli.Utils, only: [uuid: 0]

  @derive Jason.Encoder
  defstruct [:id, :content]

  def parse(%{"id" => id, "content" => content}) do
    {:ok, %__MODULE__{id: id, content: content}}
  end

  def parse(%{"content" => _}) do
    {:error, "invalid feedback: missing id"}
  end

  def parse(_) do
    {:error, "invalid feedback"}
  end

  def from_text(text) when is_binary(text) do
    %__MODULE__{
      content: %{
        "model" => [
          %{"children" => [%{"text" => text}], "id" => uuid(), "type" => "p"}
        ]
      },
      id: uuid()
    }
  end
end
