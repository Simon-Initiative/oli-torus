defmodule Oli.LearningModel.LktAoa.Contribution do
  @moduledoc """
  Pure normalization helpers for LKT-AOA inputs.

  The helpers in this module work only with already-loaded structs and maps. They
  do not read application configuration, touch the Repo, or decode raw persisted
  JSON; those boundaries belong to the later bulk application service.
  """

  alias Oli.LearningModel.Parameters
  alias Oli.LearningModel.V2.{ActivityParameters, LearningObjectiveParameters, PartParameters}
  alias Oli.Resources.Revision

  @activity_resource_type_id Oli.Resources.ResourceType.id_for_activity()
  @objective_resource_type_id Oli.Resources.ResourceType.id_for_objective()

  @enforce_keys [
    :part_attempt_id,
    :part_attempt_guid,
    :date_evaluated,
    :section_id,
    :user_id,
    :activity_id,
    :activity_revision_id,
    :part_id,
    :learning_objective_ids,
    :beta_part,
    :score,
    :out_of
  ]
  defstruct [
    :part_attempt_id,
    :part_attempt_guid,
    :date_evaluated,
    :section_id,
    :user_id,
    :activity_id,
    :activity_revision_id,
    :part_id,
    :learning_objective_ids,
    :beta_part,
    :score,
    :out_of
  ]

  @type t :: %__MODULE__{
          part_attempt_id: integer(),
          part_attempt_guid: String.t(),
          date_evaluated: DateTime.t(),
          section_id: integer(),
          user_id: integer(),
          activity_id: integer(),
          activity_revision_id: integer(),
          part_id: String.t(),
          learning_objective_ids: [integer()],
          beta_part: float(),
          score: number(),
          out_of: number()
        }

  @type evidence_key :: {integer(), integer(), integer(), String.t()}
  @type state_key :: {integer(), integer(), integer()}

  @spec objectives_for_part(Revision.t(), String.t()) :: {:ok, [integer()]} | {:error, term()}
  def objectives_for_part(%Revision{} = revision, part_id) when is_binary(part_id) do
    objectives =
      case revision.objectives do
        nil -> []
        list when is_list(list) -> list
        map when is_map(map) -> Map.get(map, part_id, [])
        invalid -> {:error, {:invalid_objective_mapping, invalid}}
      end

    case objectives do
      {:error, reason} -> {:error, reason}
      objectives -> normalize_objective_ids(objectives)
    end
  end

  def objectives_for_part(_revision, part_id), do: {:error, {:invalid_part_id, part_id}}

  @spec validate_consistent_evidence_mappings([t()]) :: :ok | {:error, term()}
  def validate_consistent_evidence_mappings(contributions) when is_list(contributions) do
    Enum.reduce_while(contributions, %{}, fn %__MODULE__{} = contribution, seen ->
      key = evidence_key(contribution)
      objectives = contribution.learning_objective_ids

      case Map.fetch(seen, key) do
        {:ok, ^objectives} ->
          {:cont, seen}

        {:ok, existing} ->
          {:halt, {:error, {:conflicting_objective_mapping, key, existing, objectives}}}

        :error ->
          {:cont, Map.put(seen, key, objectives)}
      end
    end)
    |> case do
      %{} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec confidence_increments_for_new_evidence([t()], [evidence_key()]) :: %{
          state_key() => non_neg_integer()
        }
  def confidence_increments_for_new_evidence(contributions, evidence_keys)
      when is_list(contributions) and is_list(evidence_keys) do
    new_evidence = MapSet.new(evidence_keys)

    contributions
    |> Enum.filter(fn contribution ->
      MapSet.member?(new_evidence, evidence_key(contribution))
    end)
    |> Enum.uniq_by(&evidence_key/1)
    |> Enum.flat_map(&state_keys/1)
    |> Enum.frequencies()
  end

  @spec activity_part_beta(Revision.t(), String.t()) :: {:ok, float()} | {:error, term()}
  def activity_part_beta(%Revision{} = revision, part_id) when is_binary(part_id) do
    with :ok <- require_resource_type(revision, :activity) do
      activity_part_beta_from_parameters(revision.learning_model_parameters, part_id)
    end
  end

  def activity_part_beta(%Revision{}, part_id), do: {:error, {:invalid_part_id, part_id}}

  @spec learning_objective_beta(Revision.t()) :: {:ok, float()} | {:error, term()}
  def learning_objective_beta(%Revision{} = revision) do
    with :ok <- require_resource_type(revision, :learning_objective) do
      learning_objective_beta_from_parameters(revision.learning_model_parameters)
    end
  end

  defp activity_part_beta_from_parameters(nil, _part_id), do: {:ok, 0.0}

  defp activity_part_beta_from_parameters(
         %Parameters{
           parameter_type: :activity,
           payload: %ActivityParameters{parts: parts}
         },
         part_id
       ) do
    case Map.get(parts, part_id) do
      nil -> {:ok, 0.0}
      %PartParameters{beta_difficulty: beta_part} -> {:ok, beta_part}
      invalid -> {:error, {:invalid_activity_part_parameters, part_id, invalid}}
    end
  end

  defp activity_part_beta_from_parameters(parameters, _part_id),
    do: {:error, {:invalid_activity_parameters, parameters}}

  defp learning_objective_beta_from_parameters(nil), do: {:ok, 0.0}

  defp learning_objective_beta_from_parameters(%Parameters{
         parameter_type: :learning_objective,
         payload: %LearningObjectiveParameters{beta_lo: beta_lo}
       }),
       do: {:ok, beta_lo}

  defp learning_objective_beta_from_parameters(parameters),
    do: {:error, {:invalid_learning_objective_parameters, parameters}}

  @spec correct?(t() | map()) :: boolean()
  def correct?(%__MODULE__{score: score, out_of: out_of}), do: score == out_of
  def correct?(%{score: score, out_of: out_of}), do: score == out_of

  @spec binary_outcome(t() | map()) :: 0 | 1
  def binary_outcome(contribution) do
    case correct?(contribution) do
      true -> 1
      false -> 0
    end
  end

  @spec evidence_key(t()) :: evidence_key()
  def evidence_key(%__MODULE__{} = contribution) do
    {contribution.section_id, contribution.user_id, contribution.activity_id,
     contribution.part_id}
  end

  @spec state_keys(t()) :: [state_key()]
  def state_keys(%__MODULE__{} = contribution) do
    Enum.map(contribution.learning_objective_ids, fn learning_objective_id ->
      {contribution.section_id, contribution.user_id, learning_objective_id}
    end)
  end

  @spec normalize_objective_ids(term()) :: {:ok, [integer()]} | {:error, term()}
  def normalize_objective_ids(objective_ids) when is_list(objective_ids) do
    Enum.reduce_while(objective_ids, {:ok, []}, fn
      objective_id, {:ok, ids} when is_integer(objective_id) ->
        {:cont, {:ok, [objective_id | ids]}}

      objective_id, _acc ->
        {:halt, {:error, {:invalid_objective_id, objective_id}}}
    end)
    |> case do
      {:ok, ids} -> {:ok, ids |> Enum.reverse() |> Enum.uniq() |> Enum.sort()}
      {:error, reason} -> {:error, reason}
    end
  end

  def normalize_objective_ids(objective_ids),
    do: {:error, {:invalid_objective_mapping, objective_ids}}

  defp require_resource_type(%Revision{resource_type_id: resource_type_id}, :activity)
       when resource_type_id == @activity_resource_type_id,
       do: :ok

  defp require_resource_type(%Revision{resource_type_id: resource_type_id}, :learning_objective)
       when resource_type_id == @objective_resource_type_id,
       do: :ok

  defp require_resource_type(%Revision{resource_type_id: resource_type_id}, expected),
    do: {:error, {:invalid_revision_resource_type, expected, resource_type_id}}
end
