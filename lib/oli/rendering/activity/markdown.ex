defmodule Oli.Rendering.Activity.Markdown do
  @moduledoc """
  Implements the Markdown writer for activity rendering
  """

  alias Oli.Rendering.Context
  alias Oli.Rendering.Error

  @behaviour Oli.Rendering.Activity

  def activity(
        context,
        %{"activity_id" => activity_id}
      ) do
    model =
      Map.get(context.activity_map || %{}, activity_id, %{unencoded_model: %{}})
      |> Map.get(:unencoded_model)

    stem_content =
      case Map.get(model, "stem") do
        value when is_map(value) ->
          Oli.Rendering.Content.render(
            context,
            model["stem"]["content"],
            Oli.Rendering.Content.Markdown
          )

        _ ->
          []
      end

    choices_content =
      case Map.has_key?(model, "choices") do
        true ->
          Enum.map(model["choices"], fn choice ->
            case choice do
              map when is_map(map) ->
                Oli.Rendering.Content.render(
                  context,
                  choice["content"],
                  Oli.Rendering.Content.Markdown
                )

              _ ->
                []
            end
          end)

        false ->
          []
      end

    ["\n", "Question / Activity: #{activity_id}", stem_content, choices_content, "\n\n"]
  end

  def error(%Context{} = context, element, error) do
    Error.render(context, element, error, Error.Plaintext)
  end
end
