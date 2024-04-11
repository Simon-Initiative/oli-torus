defmodule Oli.Accounts.VrUserAgent do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  schema "vr_user_agents" do
    field :user_agent, :string
  end

  def new_changeset(attrs \\ %{}) do
    changeset(%VrUserAgent{}, attrs)
  end

  def changeset(item, attrs \\ %{}) do
    item
    |> cast(attrs, [:user_agent])
    |> validate_required([:user_agent])
    |> unique_constraint(:user_agent, name: :vr_user_agents_user_agent_index)
  end
end
