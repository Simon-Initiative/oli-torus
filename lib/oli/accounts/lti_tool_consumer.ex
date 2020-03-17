defmodule Oli.Accounts.LtiToolConsumer do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_tool_consumers" do
    field :info_product_family_code, :string
    field :info_version, :string
    field :instance_contact_email, :string
    field :instance_guid, :string
    field :instance_name, :string
    has_many :lti_user_details, Oli.Accounts.LtiUserDetails
    belongs_to :institution, Oli.Accounts.Institution

    timestamps()
  end

  @doc false
  def changeset(lti_tool_consumer, attrs) do
    lti_tool_consumer
    |> cast(attrs, [:instance_guid, :instance_name, :instance_contact_email, :info_version, :info_product_family_code, :institution_id])
    |> validate_required([:instance_guid, :instance_name, :instance_contact_email, :info_version, :info_product_family_code, :institution_id])
  end
end
