defmodule Oli.Delivery.Attempts.ResourceAccess do
  use Ecto.Schema
  import Ecto.Changeset

  schema "resource_accesses" do

    field :access_count, :integer
    field :score, :decimal
    field :out_of, :decimal

    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :resource, Oli.Resources.Resource
    has_many :resource_attempts, Oli.Delivery.Attempts.ResourceAttempt

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [:access_count, :score, :out_of, :user_id, :section_id, :resource_id])
    |> validate_required([:access_count, :user_id, :section_id, :resource_id])
    |> unique_constraint(:entry, name: :resource_accesses_unique_index)

  end
end
