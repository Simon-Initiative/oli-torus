defmodule Oli.Consent.CookiesConsent do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:name, :value, :expiration]}
  schema "consent_cookies" do
    field :expiration, :utc_datetime
    field :name, :string
    field :value, :string
    belongs_to :user, Oli.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(cookies, attrs) do
    cookies
    |> cast(attrs, [:name, :value, :expiration, :user_id])
    |> validate_required([:name, :value, :expiration, :user_id])
  end
end
