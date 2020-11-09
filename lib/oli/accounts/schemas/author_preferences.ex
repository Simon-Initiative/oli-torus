defmodule Oli.Accounts.AuthorPreferences do
  use Ecto.Schema
  import Ecto.Changeset

  # embedded_schema is short for:
  #
  #   @primary_key {:id, :binary_id, autogenerate: true}
  #   schema "embedded Item" do
  #
  @primary_key false
  embedded_schema do
    field :theme, :string
  end

  def changeset(preferences, attrs \\ %{}) do
    preferences
    |> cast(attrs, [:theme])
  end
end
