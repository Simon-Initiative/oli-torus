defmodule Oli.Delivery.Proficiency.Estimate do
  @moduledoc """
  Model-neutral proficiency for one learner and one learning objective or scope.

  A missing score is intentionally different from `0.0`: zero is a valid model
  estimate, while `nil` means the provider cannot report a numeric estimate.
  Provider-specific modules own bucketing and evidence eligibility.
  """

  alias Oli.LearningModel.ModelVersion

  @type label :: :low | :medium | :high | :not_enough_information | :unavailable

  @type t :: %__MODULE__{
          section_id: pos_integer(),
          user_id: pos_integer() | nil,
          learning_objective_id: pos_integer() | nil,
          score: float() | nil,
          label: label(),
          confidence: float() | nil,
          attempt_count: non_neg_integer(),
          unique_activity_part_count: non_neg_integer(),
          learning_model_version: :naive | :lkt_aoa
        }

  @enforce_keys [:section_id, :label, :learning_model_version]
  defstruct [
    :section_id,
    :user_id,
    :learning_objective_id,
    :score,
    :label,
    :confidence,
    :learning_model_version,
    attempt_count: 0,
    unique_activity_part_count: 0
  ]

  @labels [:low, :medium, :high, :not_enough_information, :unavailable]
  @numeric_labels [:low, :medium, :high]
  @non_numeric_labels [:not_enough_information, :unavailable]
  @models ModelVersion.values()
  @fields [
    :section_id,
    :user_id,
    :learning_objective_id,
    :score,
    :label,
    :confidence,
    :attempt_count,
    :unique_activity_part_count,
    :learning_model_version
  ]

  @doc """
  Builds a validated canonical estimate.

  This validates the model-neutral shape only. A provider remains responsible for
  deciding whether a score is low, medium, or high for its model.
  """
  @spec new(map() | keyword()) :: {:ok, t()} | {:error, keyword()}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(%{} = attrs) do
    unknown_fields = Map.keys(attrs) -- @fields

    case unknown_fields do
      [] -> validate(struct(__MODULE__, attrs))
      fields -> {:error, unknown_fields: Enum.sort(fields)}
    end
  end

  defp validate(estimate) do
    case errors(estimate) do
      [] -> {:ok, estimate}
      errors -> {:error, errors}
    end
  end

  defp errors(estimate) do
    []
    |> require_positive_id(:section_id, estimate.section_id)
    |> optional_positive_id(:user_id, estimate.user_id)
    |> optional_positive_id(:learning_objective_id, estimate.learning_objective_id)
    |> probability(:score, estimate.score)
    |> probability(:confidence, estimate.confidence)
    |> non_negative_integer(:attempt_count, estimate.attempt_count)
    |> non_negative_integer(
      :unique_activity_part_count,
      estimate.unique_activity_part_count
    )
    |> valid_label(estimate.label)
    |> valid_model(estimate.learning_model_version)
    |> consistent_score_and_label(estimate.score, estimate.label)
    |> Enum.reverse()
  end

  defp require_positive_id(errors, _field, value) when is_integer(value) and value > 0,
    do: errors

  defp require_positive_id(errors, field, _value), do: [{field, :must_be_positive} | errors]

  defp optional_positive_id(errors, _field, nil), do: errors

  defp optional_positive_id(errors, _field, value) when is_integer(value) and value > 0,
    do: errors

  defp optional_positive_id(errors, field, _value), do: [{field, :must_be_positive} | errors]

  defp probability(errors, _field, nil), do: errors

  defp probability(errors, _field, value)
       when is_number(value) and value >= 0.0 and value <= 1.0,
       do: errors

  defp probability(errors, field, _value), do: [{field, :must_be_probability} | errors]

  defp non_negative_integer(errors, _field, value) when is_integer(value) and value >= 0,
    do: errors

  defp non_negative_integer(errors, field, _value),
    do: [{field, :must_be_non_negative_integer} | errors]

  defp valid_label(errors, label) when label in @labels, do: errors
  defp valid_label(errors, _label), do: [{:label, :unsupported} | errors]

  defp valid_model(errors, model) when model in @models, do: errors
  defp valid_model(errors, _model), do: [{:learning_model_version, :unsupported} | errors]

  defp consistent_score_and_label(errors, nil, label) when label in @non_numeric_labels,
    do: errors

  defp consistent_score_and_label(errors, score, label)
       when is_number(score) and label in @numeric_labels,
       do: errors

  defp consistent_score_and_label(errors, _score, _label),
    do: [{:score, :inconsistent_with_label} | errors]
end
