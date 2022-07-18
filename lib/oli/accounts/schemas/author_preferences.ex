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
    field :admin_show_all_projects, :boolean, default: true
    field :admin_show_deleted_projects, :boolean, default: false
    field :show_relative_dates, :boolean, default: true
    field :timezone, :string
  end

  def changeset(preferences, attrs \\ %{}) do
    preferences
    |> cast(attrs, [
      :admin_show_all_projects,
      :admin_show_deleted_projects,
      :show_relative_dates,
      :timezone
    ])
  end
end
