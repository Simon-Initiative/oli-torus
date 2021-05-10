defmodule Oli.Utils.LoadTesting do
  def enabled?() do
    Application.fetch_env!(:oli, :load_testing_mode) == :enabled
  end

  @doc """
  For a given activity type slug and the transformed activity model, construct JSON
  that represents a collection of valid answers (not necessarily correct) to all parts. Represent
  this as a map of part ids to each answer.

  For unsupported parts (or entire activities), simply omit those parts from the returned map.
  """
  def provide_answers(activity_type_slug, transformed_model) do
    case activity_type_slug do
      "oli_check_all_that_apply" ->
        Map.put(%{}, get_first_part_id(transformed_model), %{
          "input" => choices(transformed_model) |> hd
        })

      "oli_multiple_choice" ->
        Map.put(%{}, get_first_part_id(transformed_model), %{
          "input" => choices(transformed_model) |> hd
        })

      "oli_ordering" ->
        Map.put(%{}, get_first_part_id(transformed_model), %{
          "input" => choices(transformed_model) |> Enum.join(" ")
        })

      "oli_short_answer" ->
        input =
          case Map.get(transformed_model, "inputType", "text") do
            "text" -> "answer"
            "textarea" -> "longer answer"
            "numeric" -> 0
          end

        Map.put(%{}, get_first_part_id(transformed_model), %{"input" => input})

      _ ->
        %{}
    end
  end

  defp get_first_part_id(transformed_model) do
    transformed_model["authoring"]["parts"] |> hd |> Map.get("id")
  end

  defp choices(transformed_model) do
    transformed_model["choices"]
    |> Enum.map(fn c -> c["id"] end)
  end
end
