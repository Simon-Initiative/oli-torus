defmodule Oli.Delivery.Proficiency.Aggregate do
  @moduledoc """
  Model-neutral aggregate proficiency and its coverage metadata.

  Numeric proficiency, categorical distribution, and coverage counts stay
  separate so confidence or missing evidence can never modify a proficiency
  score implicitly.
  """

  alias Oli.Delivery.Proficiency.Estimate

  @type t :: %__MODULE__{
          estimate: Estimate.t() | nil,
          numeric_score: float() | nil,
          distribution: %{optional(Estimate.label()) => non_neg_integer()},
          contributing_count: non_neg_integer(),
          eligible_count: non_neg_integer(),
          total_count: non_neg_integer(),
          coverage: map()
        }

  defstruct estimate: nil,
            numeric_score: nil,
            distribution: %{},
            contributing_count: 0,
            eligible_count: 0,
            total_count: 0,
            coverage: %{}

  @labels [:low, :medium, :high, :not_enough_information, :unavailable]
  @fields [
    :estimate,
    :numeric_score,
    :distribution,
    :contributing_count,
    :eligible_count,
    :total_count,
    :coverage
  ]

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, keyword()}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(%{} = attrs) do
    unknown_fields = Map.keys(attrs) -- @fields

    case unknown_fields do
      [] -> validate(struct!(__MODULE__, attrs))
      fields -> {:error, unknown_fields: Enum.sort(fields)}
    end
  end

  defp validate(aggregate) do
    case errors(aggregate) do
      [] -> {:ok, aggregate}
      errors -> {:error, errors}
    end
  end

  defp errors(aggregate) do
    []
    |> valid_estimate(aggregate.estimate)
    |> probability(:numeric_score, aggregate.numeric_score)
    |> valid_distribution(aggregate.distribution)
    |> non_negative_integer(:contributing_count, aggregate.contributing_count)
    |> non_negative_integer(:eligible_count, aggregate.eligible_count)
    |> non_negative_integer(:total_count, aggregate.total_count)
    |> ordered_counts(aggregate)
    |> valid_coverage(aggregate.coverage)
    |> Enum.reverse()
  end

  defp valid_estimate(errors, nil), do: errors
  defp valid_estimate(errors, %Estimate{}), do: errors
  defp valid_estimate(errors, _estimate), do: [{:estimate, :invalid} | errors]

  defp probability(errors, _field, nil), do: errors

  defp probability(errors, _field, value)
       when is_number(value) and value >= 0.0 and value <= 1.0,
       do: errors

  defp probability(errors, field, _value), do: [{field, :must_be_probability} | errors]

  defp valid_distribution(errors, distribution) when is_map(distribution) do
    if Enum.all?(distribution, fn {label, count} ->
         label in @labels and is_integer(count) and count >= 0
       end) do
      errors
    else
      [{:distribution, :invalid} | errors]
    end
  end

  defp valid_distribution(errors, _distribution), do: [{:distribution, :invalid} | errors]

  defp non_negative_integer(errors, _field, value) when is_integer(value) and value >= 0,
    do: errors

  defp non_negative_integer(errors, field, _value),
    do: [{field, :must_be_non_negative_integer} | errors]

  defp ordered_counts(errors, %{
         contributing_count: contributing,
         eligible_count: eligible,
         total_count: total
       })
       when is_integer(contributing) and is_integer(eligible) and is_integer(total) and
              contributing <= eligible and eligible <= total,
       do: errors

  defp ordered_counts(errors, _aggregate), do: [{:counts, :out_of_order} | errors]

  defp valid_coverage(errors, coverage) when is_map(coverage), do: errors
  defp valid_coverage(errors, _coverage), do: [{:coverage, :must_be_map} | errors]
end
