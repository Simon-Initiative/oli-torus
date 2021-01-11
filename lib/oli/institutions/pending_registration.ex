defmodule Oli.Institutions.PendingRegistration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pending_registrations" do
    field :country_code, :string
    field :institution_email, :string
    field :institution_url, :string
    field :name, :string
    field :timezone, :string

    field :issuer, :string
    field :client_id, :string
    field :key_set_url, :string
    field :auth_token_url, :string
    field :auth_login_url, :string
    field :auth_server, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(pending_registration, attrs \\ %{}) do
    pending_registration
    |> cast(attrs, [
      :name,
      :country_code,
      :institution_email,
      :institution_url,
      :timezone,
      :issuer,
      :client_id,
      :key_set_url,
      :auth_token_url,
      :auth_login_url,
      :auth_server
    ])
    |> validate_required([
      :name,
      :country_code,
      :institution_email,
      :institution_url,
      :timezone,
      :issuer,
      :client_id,
      :key_set_url,
      :auth_token_url,
      :auth_login_url,
      :auth_server
    ])
  end

  def institution_attrs(%Oli.Institutions.PendingRegistration{} = pending_registration) do
    Map.from_struct(pending_registration)
    |> Map.take([
      :name,
      :country_code,
      :institution_email,
      :institution_url,
      :timezone
    ])
  end

  def registration_attrs(%Oli.Institutions.PendingRegistration{} = pending_registration) do
    Map.from_struct(pending_registration)
    |> Map.take([
      :issuer,
      :client_id,
      :key_set_url,
      :auth_token_url,
      :auth_login_url,
      :auth_server
    ])
  end
end
