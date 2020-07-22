defmodule Oli.Activities.Model.Hint do

  @derive Jason.Encoder
  defstruct [:id, :content]

  def parse(%{"id" => id, "content" => content }) do
    {:ok, %Oli.Activities.Model.Hint{id: id, content: content}}
  end

  def parse(%{"content" => _ }) do
    {:error, "invalid hint: missing id"}
  end

  def parse(hints) when is_list(hints) do
    Enum.map(hints, &parse/1)
    |> Oli.Activities.ParseUtils.items_or_errors()
  end

  def parse(_) do
    {:error, "invalid hint"}
  end

end
