defmodule Oli.Delivery.Section do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sections" do
    timestamps()
    field :title, :string
    field :start_date, :date
    field :end_date, :date
    field :time_zone, :string
    belongs_to :institution, Oli.Accounts.Institution
    field :open_and_free, :boolean
    field :registration_open, :boolean
  end

  @doc false
  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [
      :title,
      :start_date,
      :end_date,
      :time_zone,
      :institution,
      :open_and_free,
      :registration_open
    ])
    |> validate_required([
      :title,
      :start_date,
      :end_date,
      :time_zone,
      :institution,
      :open_and_free,
      :registration_open
    ])
  end
end
