defmodule OliWeb.Workspaces.CourseAuthor.ExperimentConfigurationForm do
  @moduledoc """
  Form boundary for casting and validating experiment configuration submitted by authors.

  Domain authorization, lifecycle, and algorithm compatibility remain owned by
  `Oli.Experiments`.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @scalar_fields [
    :alternatives_resource_id,
    :assignment_scope,
    :prior_alpha,
    :prior_beta,
    :warm_up_assignments,
    :max_condition_share,
    :fixed_control_allocation,
    :imbalance_threshold
  ]

  embedded_schema do
    field :algorithm, Ecto.Enum, values: [:weighted_random, :thompson_sampling]
    field :assignment_scope, Ecto.Enum, values: [:intervention, :section_enrollment]
    field :alternatives_resource_id, :integer
    field :conditions, {:array, :map}, virtual: true, default: []
    field :interventions, {:array, :map}, virtual: true, default: []
    field :prior_alpha, :float
    field :prior_beta, :float
    field :warm_up_assignments, :integer
    field :max_condition_share, :float
    field :fixed_control_allocation, :float
    field :imbalance_threshold, :float
  end

  @type t :: %__MODULE__{}

  @doc "Builds a form struct from an experiment configuration map."
  @spec from_configuration(map() | t()) :: t()
  def from_configuration(%__MODULE__{} = form), do: form

  def from_configuration(configuration) when is_map(configuration) do
    fields = __schema__(:fields) ++ __schema__(:virtual_fields)
    struct!(__MODULE__, Map.take(configuration, fields))
  end

  @doc "Casts the editable scalar fields and tracks nested configuration changes."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = form, configuration) do
    form
    |> cast(Map.take(configuration, @scalar_fields), @scalar_fields)
    |> put_change_if_different(:algorithm, configuration.algorithm)
    |> put_change_if_different(:conditions, configuration.conditions)
    |> put_change_if_different(:interventions, configuration.interventions)
  end

  @doc "Casts and requires the assignment scope submitted by the configuration form."
  @spec cast_assignment_scope(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def cast_assignment_scope(params) do
    %__MODULE__{}
    |> cast(params, [:assignment_scope])
    |> validate_required(:assignment_scope)
    |> apply_action(:validate)
  end

  @doc "Returns the first validation message for each invalid form field."
  @spec field_errors(Ecto.Changeset.t()) :: %{optional(atom()) => String.t()}
  def field_errors(changeset) do
    traverse_errors(changeset, fn {message, _opts} -> message end)
    |> Map.new(fn {field, messages} -> {field, List.first(messages)} end)
  end

  defp put_change_if_different(changeset, field, value) do
    case Map.fetch!(changeset.data, field) == value do
      true -> changeset
      false -> put_change(changeset, field, value)
    end
  end
end
