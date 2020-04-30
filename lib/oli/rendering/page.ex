defmodule Oli.Rendering.Page do
  alias Oli.Rendering.Context

  @callback content(%Context{}, %{}) :: [any()]
  @callback activity(%Context{}, %{}) :: [any()]
  @callback unsupported(%Context{}, %{}) :: [any()]

  def render(%Context{} = context, page_model, format) when is_list(page_model) do
    Enum.map(page_model, fn element ->
      case element do
        %{"type" => "content"} ->
          format.content(context, element)
        %{"type" => "activity-reference"} ->
          format.activity(context, element)
        _ ->
          format.unsupported(context, element)
      end
    end)
  end

end
