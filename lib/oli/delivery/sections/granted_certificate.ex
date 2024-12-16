defmodule Oli.Delivery.Sections.GrantedCertificate do
  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections.Certificate

  @state_enum [:pending, :earned, :denied]
  @issued_by_type_enum [:user, :author]

  schema "granted_certificates" do
    field :state, Ecto.Enum, values: @state_enum
    field :with_distinction, :boolean
    field :guid, :string
    field :issued_by, :integer
    field :issued_by_type, Ecto.Enum, values: @issued_by_type_enum, default: :user
    field :issued_at, :utc_datetime

    belongs_to :certificate, Certificate
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @required_fields [:user_id, :certificate_id, :state, :with_distinction, :guid]
  @optional_fields [:issued_by, :issued_by_type, :issued_at]

  @all_fields @required_fields ++ @optional_fields

  def changeset(params \\ %{}) do
    changeset(%__MODULE__{}, params)
  end

  def changeset(granted_certificates, params) do
    granted_certificates
    |> cast(params, @all_fields)
    |> validate_required(@required_fields)
    |> assoc_constraint(:certificate)
    |> assoc_constraint(:user)
    |> unique_constraint([:user_id, :certificate_id],
      name: :unique_user_certificate,
      message: "has already been granted this type of certificate"
    )
  end
end
