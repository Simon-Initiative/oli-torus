defmodule Oli.Lti_1p3.LoginHint do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_1p3_login_hints" do
    field :value, :string

    belongs_to :user, Oli.Accounts.User
    belongs_to :author, Oli.Accounts.Author

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(login_hint, attrs) do
    login_hint
    |> cast(attrs, [:value, :user_id, :author_id])
    |> validate_required([:value])
    |> unique_constraint(:value)
  end
end
