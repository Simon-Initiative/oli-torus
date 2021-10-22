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
    field :admin_show_all_projects, :boolean
    field :admin_show_deleted_projects, :boolean
  end

  def changeset(preferences, attrs \\ %{}) do
    preferences
    |> cast(attrs, [
      :admin_show_all_projects,
      :admin_show_deleted_projects
    ])
  end
end
