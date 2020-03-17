defmodule Oli.Accounts.LtiUserDetails do
  use Ecto.Schema
  import Ecto.Changeset

  schema "lti_user_details" do
    field :lti_user_id, :string
    field :lti_user_image, :string
    field :lti_roles, :string
    belongs_to :user, Oli.Accounts.User
    belongs_to :lti_tool_consumer, Oli.Accounts.LtiToolConsumer

    timestamps()
  end

  @doc false
  def changeset(lti_user_details, attrs) do
    lti_user_details
    |> cast(attrs, [:lti_user_id, :lti_user_image, :lti_roles, :user_id, :lti_tool_consumer_id])
    |> validate_required([:lti_user_id, :lti_user_image, :lti_roles])
  end
end
