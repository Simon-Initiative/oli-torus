defmodule Oli.Lti_1p3.PlatformInstance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_1p3_platform_instances" do
    field :client_id, :string
    field :custom_params, :string
    field :description, :string
    field :keyset_url, :string
    field :login_url, :string
    field :name, :string
    field :redirect_uris, :string
    field :target_link_uri, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(platform_instance, attrs) do
    platform_instance
    |> cast(attrs, [:name, :description, :target_link_uri, :client_id, :login_url, :keyset_url, :redirect_uris, :custom_params])
    |> validate_required([:name, :target_link_uri, :client_id, :login_url, :keyset_url, :redirect_uris])
  end
end
