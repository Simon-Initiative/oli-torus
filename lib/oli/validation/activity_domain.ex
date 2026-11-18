defmodule Oli.Validation.ActivityDomain do
  @moduledoc "Separate, pure domain validation of schema-valid Basic Page activity models."
  alias Oli.Validation.ActivityContracts
  alias Oli.Validation.ActivityDomain.{IDs, Issue, Limits, Rules}

  @doc "Checks logical IDs and matching contracts, returning at most 100 structured issues."
  @spec validate(String.t(), term()) :: :ok | {:error, [Issue.t()]}
  def validate(slug, model) do
    with {:ok, policy} <- policy(slug),
         :ok <- Limits.check(model),
         :ok <- shape(model) do
      issues = (IDs.check(slug, model) ++ Rules.check(model, policy, slug)) |> Enum.take(100)

      case issues do
        [] -> :ok
        _ -> {:error, issues}
      end
    end
  end

  defp policy(slug) do
    case ActivityContracts.fetch(slug) do
      {:ok, %{domain: policy}} when policy != :unsupported ->
        {:ok, policy}

      _ ->
        {:error,
         [
           Issue.new(
             "unsupported_activity_type",
             [],
             "Domain validation is not available for this activity type"
           )
         ]}
    end
  end

  # Defensive direct-call checks, not a second schema validator. The public
  # precondition is a successful explicit JSON Schema validation step.
  defp shape(%{"authoring" => %{"parts" => parts}} = model) when is_list(parts) do
    valid =
      Enum.all?(parts, fn
        %{"id" => id, "responses" => responses} when is_binary(id) and is_list(responses) ->
          Enum.all?(responses, fn response ->
            is_map(response) and
              (not Map.has_key?(response, "rule") or is_binary(response["rule"])) and
              (not Map.has_key?(response, "matchConfig") or is_map(response["matchConfig"]))
          end)

        _ ->
          false
      end) and
        Enum.all?(["inputs", "choices", "items", "feedback"], fn key ->
          case Map.get(model, key, []) do
            entries when is_list(entries) -> Enum.all?(entries, &is_map/1)
            _ -> false
          end
        end)

    valid =
      valid and
        Enum.all?(Map.get(model, "inputs", []), fn input -> is_binary(input["partId"]) end) and
        case model["authoring"]["transformations"] do
          nil -> true
          values when is_list(values) -> Enum.all?(values, &is_map/1)
          _ -> false
        end

    case valid do
      true -> :ok
      false -> invalid_shape()
    end
  end

  defp shape(_), do: invalid_shape()

  defp invalid_shape,
    do:
      {:error,
       [
         Issue.new(
           "invalid_input_shape",
           [],
           "Domain validation requires a schema-valid activity model"
         )
       ]}
end
