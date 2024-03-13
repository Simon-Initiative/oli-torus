defmodule Oli.Accounts.Schemas.VrUserAgent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:user_id, :id, []}
  schema "vr_user_agents" do
    field :value, :boolean, default: false
    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [:user_id, :value])
  end
end
