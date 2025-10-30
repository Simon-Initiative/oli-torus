defmodule Oli.ScopedFeatureFlags.ScopedFeatureExemption do
  @moduledoc """
  Records publisher-level overrides for canary rollouts.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Accounts.Author
  alias Oli.Inventories.Publisher

  @effects [:deny, :force_enable]

  schema "scoped_feature_exemptions" do
    field :feature_name, :string
    field :effect, Ecto.Enum, values: @effects
    field :note, :string

    belongs_to :publisher, Publisher
    belongs_to :updated_by_author, Author, foreign_key: :updated_by_author_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(exemption, attrs \\ %{}) do
    exemption
    |> cast(attrs, [:feature_name, :publisher_id, :effect, :note, :updated_by_author_id])
    |> validate_required([:feature_name, :publisher_id, :effect])
    |> validate_length(:feature_name, min: 1, max: 255)
    |> validate_length(:note, max: 1000)
    |> foreign_key_constraint(:publisher_id)
  end
end
