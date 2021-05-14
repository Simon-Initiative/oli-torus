defmodule Oli.Accounts.AuthorPreferences do
  use Ecto.Schema
  import Ecto.Changeset

  # embedded_schema is short for:
  #
  #   @primary_key {:id, :binary_id, autogenerate: true}
  #   schema "embedded Item" do
  #
  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :theme, :string
    field :live_preview_display, :string
    field :curriculum_view, :string
  end

  def changeset(preferences, attrs \\ %{}) do
    preferences
    |> cast(attrs, [:theme, :live_preview_display, :curriculum_view])
  end
end
