defmodule Oli.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user" do
    field :email, :string, default: ""
    field :first_name, :string, default: ""
    field :last_name, :string, default: ""
    field :user_id, :string
    field :user_image, :string
    field :roles, :string

    # TODO: Remove when LTI 1.3 GS replaces canvas api for grade passback
    field :canvas_id, :string

    belongs_to :author, Oli.Accounts.Author
    belongs_to :lti_tool_consumer, Oli.Accounts.LtiToolConsumer
    belongs_to :institution, Oli.Accounts.Institution

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :first_name, :last_name, :user_id, :user_image, :roles, :canvas_id, :lti_tool_consumer_id, :institution_id, :author_id])
    |> validate_required([:user_id, :user_image, :roles, :lti_tool_consumer_id])
    |> validate_not_nil([:email, :first_name, :last_name])
  end

  defp validate_not_nil(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      if get_field(changeset, field) == nil do
        add_error(changeset, field, "nil")
      else
        changeset
      end
    end)
  end
end
