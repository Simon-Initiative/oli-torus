defmodule Oli.LearningModel.Parameters.Validation do
  @moduledoc """
  Revision-aware validation and inherited-part reconciliation for parameters.
  """

  alias Oli.LearningModel.{Parameters, PartIds}
  alias Oli.LearningModel.V2.ActivityParameters
  alias Oli.Resources.ResourceType

  @objective_resource_type_id ResourceType.id_for_objective()
  @activity_resource_type_id ResourceType.id_for_activity()
  @diagnostic_part_limit 5
  @diagnostic_character_limit 80

  @type validation_error :: {:learning_model_parameters, String.t()}

  @spec validate_for_revision(Parameters.t() | nil, integer(), map()) ::
          :ok | {:error, [validation_error()]}
  def validate_for_revision(parameters, resource_type_id, content) do
    with {:ok, normalized} <- Parameters.decode(parameters),
         :ok <- validate_resource_type(normalized, resource_type_id),
         :ok <- validate_activity_parts(normalized, content) do
      :ok
    else
      {:error, reason} when is_tuple(reason) ->
        {:error, [learning_model_parameters: format_error(reason)]}

      {:error, errors} when is_list(errors) ->
        {:error, errors}
    end
  end

  @spec reconcile_inherited_parts(Parameters.t() | nil, map()) :: Parameters.t() | nil
  def reconcile_inherited_parts(nil, _content), do: nil

  def reconcile_inherited_parts(
        %Parameters{
          parameter_type: :activity,
          payload: %ActivityParameters{parts: parts} = payload
        } = parameters,
        content
      ) do
    valid_part_ids = PartIds.for_content(content)
    retained_parts = Map.filter(parts, fn {part_id, _parameters} -> part_id in valid_part_ids end)

    %{parameters | payload: %{payload | parts: retained_parts}}
  end

  def reconcile_inherited_parts(%Parameters{} = parameters, _content), do: parameters

  defp validate_resource_type(nil, _resource_type_id), do: :ok

  defp validate_resource_type(
         %Parameters{parameter_type: :learning_objective},
         resource_type_id
       )
       when resource_type_id == @objective_resource_type_id,
       do: :ok

  defp validate_resource_type(%Parameters{parameter_type: :activity}, resource_type_id)
       when resource_type_id == @activity_resource_type_id,
       do: :ok

  defp validate_resource_type(%Parameters{parameter_type: parameter_type}, _resource_type_id),
    do: {:error, {:parameter_type_resource_mismatch, parameter_type}}

  defp validate_activity_parts(nil, _content), do: :ok

  defp validate_activity_parts(%Parameters{parameter_type: :learning_objective}, _content),
    do: :ok

  defp validate_activity_parts(
         %Parameters{parameter_type: :activity, payload: %ActivityParameters{parts: parts}},
         content
       ) do
    known_part_ids = PartIds.for_content(content)

    {unknown_part_ids, unknown_count} =
      Enum.reduce(Map.keys(parts), {[], 0}, fn part_id, {sample, count} ->
        if MapSet.member?(known_part_ids, part_id) do
          {sample, count}
        else
          sample =
            if length(sample) < @diagnostic_part_limit, do: [part_id | sample], else: sample

          {sample, count + 1}
        end
      end)

    case unknown_count do
      0 -> :ok
      count -> {:error, {:unknown_activity_part_ids, Enum.reverse(unknown_part_ids), count}}
    end
  end

  defp format_error({:parameter_type_resource_mismatch, parameter_type}),
    do: "parameter type #{parameter_type} does not match the Revision resource type"

  defp format_error({:unknown_activity_part_ids, part_ids, count}) do
    sample = Enum.map_join(part_ids, ", ", &String.slice(&1, 0, @diagnostic_character_limit))
    omitted = if count > length(part_ids), do: " (+#{count - length(part_ids)} more)", else: ""

    "unknown activity part IDs: #{sample}#{omitted}"
  end

  defp format_error(reason),
    do: "invalid learning-model parameters: #{inspect(reason, limit: 5, printable_limit: 200)}"
end
