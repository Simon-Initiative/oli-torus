defmodule Oli.Certificates.Certificate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "certificates" do
    field :certificate_url, :string

    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Sections.Section

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(certificate, attrs) do
    certificate
    |> cast(attrs, [:user_id, :section_id, :certificate_url])
    |> validate_required([:user_id, :section_id, :certificate_url])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:section_id)
    |> unique_constraint([:user_id, :section_id], name: :unique_user_section)
    |> unique_constraint(:certificate_url, name: :unique_certificate_url)
  end
end
