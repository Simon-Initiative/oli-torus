defmodule Oli.MCP.Auth.BearerTokenUsage do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer(),
          bearer_token_id: integer(),
          event_type: String.t(),
          tool_name: String.t() | nil,
          resource_uri: String.t() | nil,
          occurred_at: DateTime.t(),
          request_id: String.t() | nil,
          status: String.t() | nil,
          bearer_token: Oli.MCP.Auth.BearerToken.t()
        }

  @event_types ~w(init tool resource)
  @statuses ~w(success error)

  schema "mcp_bearer_token_usages" do
    field :event_type, :string
    field :tool_name, :string
    field :resource_uri, :string
    field :occurred_at, :utc_datetime
    field :request_id, :string
    field :status, :string

    belongs_to :bearer_token, Oli.MCP.Auth.BearerToken
  end

  @doc false
  def changeset(usage, attrs) do
    usage
    |> cast(attrs, [
      :bearer_token_id,
      :event_type,
      :tool_name,
      :resource_uri,
      :occurred_at,
      :request_id,
      :status
    ])
    |> validate_required([:bearer_token_id, :event_type, :occurred_at])
    |> validate_inclusion(:event_type, @event_types)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:bearer_token_id)
    |> validate_event_type_fields()
  end

  defp validate_event_type_fields(changeset) do
    event_type = get_field(changeset, :event_type)

    case event_type do
      "tool" ->
        validate_required(changeset, [:tool_name])

      "resource" ->
        validate_required(changeset, [:resource_uri])

      _ ->
        changeset
    end
  end

  @doc """
  Returns the list of valid event types.
  """
  def event_types, do: @event_types

  @doc """
  Returns the list of valid statuses.
  """
  def statuses, do: @statuses
end