defmodule Oli.Conversation.ConversationMessage do
  use Ecto.Schema

  import Ecto.Changeset
  import Oli.Conversation.Common

  @derive {Jason.Encoder, only: [:role, :content, :token_length, :user_id, :resource_id]}
  schema "conversation_messages" do
    field :role, Ecto.Enum, values: [:system, :user, :assistant, :function]

    # content of the message
    field :content, :string

    # function name
    field :name, :string

    # estimated token length of the message
    field :token_length, :integer

    field :user_id, :id
    field :resource_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :name, :user_id, :resource_id])
    |> validate_required([:role, :content, :user_id])
    |> set_token_length()
  end

  defp set_token_length(changeset) do
    case get_field(changeset, :content) do
      nil -> changeset
      content -> put_change(changeset, :token_length, estimate_token_length(content))
    end
  end
end
