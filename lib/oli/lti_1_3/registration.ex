defmodule Oli.Lti_1_3.Registration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_1_3_registrations" do
    field :issuer, :string
    field :client_id, :string
    field :key_set_url, :string
    field :auth_token_url, :string
    field :auth_login_url, :string
    field :auth_server, :string
    field :tool_private_key, :string
    field :kid, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(registration, attrs) do
    registration
    |> cast(attrs, [:issuer, :client_id, :key_set_url, :auth_token_url, :auth_login_url, :auth_server, :tool_private_key, :kid])
    |> validate_required([:issuer, :client_id, :key_set_url, :auth_token_url, :auth_login_url, :auth_server, :tool_private_key, :kid])
  end
end
