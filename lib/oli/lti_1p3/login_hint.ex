defmodule Oli.Lti_1p3.LoginHint do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_1p3_login_hints" do
    field :value, :string
    field :session_user_id, :integer
    field :context, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(login_hint, attrs) do
    login_hint
    |> cast(attrs, [:value, :session_user_id, :context])
    |> validate_required([:value, :session_user_id])
    |> unique_constraint(:value)
  end
end
