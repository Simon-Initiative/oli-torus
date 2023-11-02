defmodule Oli.Lti.Tool.Registration do
  use Ecto.Schema
  import Ecto.Changeset
  import Oli.Utils, only: [update_changes: 3]

  schema "lti_1p3_registrations" do
    field(:issuer, :string)
    field(:client_id, :string)
    field(:key_set_url, :string)
    field(:auth_token_url, :string)
    field(:auth_login_url, :string)
    field(:auth_server, :string)
    field(:line_items_service_domain, :string)

    belongs_to(:tool_jwk, Lti_1p3.DataProviders.EctoProvider.Jwk, foreign_key: :tool_jwk_id)

    has_many(:deployments, Oli.Lti.Tool.Deployment)

    field :deployments_count, :integer, virtual: true
    field :total_count, :integer, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(registration, attrs \\ %{}) do
    registration
    |> cast(attrs, [
      :issuer,
      :client_id,
      :key_set_url,
      :auth_token_url,
      :auth_login_url,
      :auth_server,
      :tool_jwk_id,
      :line_items_service_domain
    ])
    |> validate_required([
      :issuer,
      :client_id,
      :key_set_url,
      :auth_token_url,
      :auth_login_url,
      :auth_server,
      :tool_jwk_id
    ])
    |> update_changes(
      [
        :issuer,
        :client_id,
        :key_set_url,
        :auth_token_url,
        :auth_login_url,
        :auth_server,
        :line_items_service_domain
      ],
      &maybe_trim/1
    )
  end

  defp maybe_trim(value) when is_binary(value) and not is_nil(value), do: String.trim(value)
  defp maybe_trim(value), do: value
end
