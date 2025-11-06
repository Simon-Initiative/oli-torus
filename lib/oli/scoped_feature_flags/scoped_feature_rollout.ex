defmodule Oli.ScopedFeatureFlags.ScopedFeatureRollout do
  @moduledoc """
  Persistent rollout state for scoped feature flags.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Accounts.Author

  @stages [:off, :internal_only, :five_percent, :fifty_percent, :full]
  @scope_types [:global, :project, :section]

  @type stage :: :off | :internal_only | :five_percent | :fifty_percent | :full
  @type scope_type :: :global | :project | :section

  def stages, do: @stages
  def scope_types, do: @scope_types

  schema "scoped_feature_rollouts" do
    field :feature_name, :string
    field :scope_type, Ecto.Enum, values: @scope_types
    field :scope_id, :integer
    field :stage, Ecto.Enum, values: @stages
    field :rollout_percentage, :integer, default: 0

    belongs_to :updated_by_author, Author, foreign_key: :updated_by_author_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(rollout, attrs \\ %{}) do
    rollout
    |> cast(attrs, [
      :feature_name,
      :scope_type,
      :scope_id,
      :stage,
      :rollout_percentage,
      :updated_by_author_id
    ])
    |> validate_required([:feature_name, :scope_type, :stage, :rollout_percentage])
    |> validate_length(:feature_name, min: 1, max: 255)
    |> validate_number(:rollout_percentage,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> maybe_normalize_scope_id()
    |> validate_scope_presence()
  end

  defp maybe_normalize_scope_id(changeset) do
    case get_field(changeset, :scope_type) do
      :global ->
        put_change(changeset, :scope_id, nil)

      _ ->
        changeset
    end
  end

  defp validate_scope_presence(changeset) do
    scope_type = get_field(changeset, :scope_type)
    scope_id = get_field(changeset, :scope_id)

    cond do
      is_nil(scope_type) ->
        changeset

      scope_type == :global ->
        changeset

      is_nil(scope_id) ->
        add_error(changeset, :scope_id, "must be present for #{scope_type} scope")

      scope_id <= 0 ->
        add_error(changeset, :scope_id, "must be a positive integer")

      true ->
        changeset
    end
  end
end
