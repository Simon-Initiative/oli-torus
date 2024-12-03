defmodule Oli.Accounts.UserPreferences do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder
  @primary_key false
  embedded_schema do
    field :timezone, :string
    field :page_outline_panel_active?, :boolean, default: false
  end

  def changeset(preferences, attrs \\ %{}) do
    preferences
    |> cast(attrs, [:timezone, :page_outline_panel_active?])
  end
end
