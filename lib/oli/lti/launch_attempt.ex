defmodule Oli.Lti.LaunchAttempt do
  @moduledoc """
  Database-backed authority for a single LTI launch lifecycle.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Oli.Accounts.User

  @type t :: %__MODULE__{}

  @flow_modes [:legacy_session, :storage_assisted]
  @transport_methods [:session_storage, :lti_storage_target]
  @lifecycle_states [
    :pending_launch,
    :launching,
    :launch_succeeded,
    :launch_failed,
    :registration_handoff,
    :expired
  ]
  @failure_classifications [
    :missing_state,
    :mismatched_state,
    :expired_state,
    :consumed_state,
    :invalid_registration,
    :invalid_deployment,
    :validation_failure,
    :storage_blocked,
    :launch_handler_failure,
    :post_auth_landing_failure,
    :unknown
  ]
  @handoff_types [:registration_request]

  @required_fields [
    :state_token,
    :nonce,
    :flow_mode,
    :transport_method,
    :lifecycle_state,
    :expires_at
  ]
  @optional_fields [
    :failure_classification,
    :handoff_type,
    :issuer,
    :client_id,
    :deployment_id,
    :context_id,
    :resource_link_id,
    :message_type,
    :target_link_uri,
    :roles,
    :launch_presentation,
    :resolved_section_id,
    :user_id,
    :launched_at,
    :consumed_at
  ]

  schema "lti_launch_attempts" do
    field :state_token, :string
    field :nonce, :string
    field :flow_mode, Ecto.Enum, values: @flow_modes
    field :transport_method, Ecto.Enum, values: @transport_methods
    field :lifecycle_state, Ecto.Enum, values: @lifecycle_states, default: :pending_launch
    field :failure_classification, Ecto.Enum, values: @failure_classifications
    field :handoff_type, Ecto.Enum, values: @handoff_types

    field :issuer, :string
    field :client_id, :string
    field :deployment_id, :string
    field :context_id, :string
    field :resource_link_id, :string
    field :message_type, :string
    field :target_link_uri, :string
    field :roles, {:array, :string}, default: []
    field :launch_presentation, :map, default: %{}

    field :resolved_section_id, :integer
    field :expires_at, :utc_datetime
    field :launched_at, :utc_datetime
    field :consumed_at, :utc_datetime

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(launch_attempt, attrs) do
    launch_attempt
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_length(:state_token, min: 8, max: 255)
    |> validate_length(:nonce, min: 8, max: 255)
    |> validate_change(:expires_at, fn :expires_at, expires_at ->
      case DateTime.compare(expires_at, DateTime.utc_now() |> DateTime.truncate(:second)) do
        :gt -> []
        _ -> [expires_at: "must be in the future"]
      end
    end)
    |> validate_terminal_fields()
    |> unique_constraint(:state_token)
  end

  @spec flow_modes() :: [atom()]
  def flow_modes, do: @flow_modes

  @spec transport_methods() :: [atom()]
  def transport_methods, do: @transport_methods

  @spec lifecycle_states() :: [atom()]
  def lifecycle_states, do: @lifecycle_states

  @spec active_lifecycle_states() :: [atom()]
  def active_lifecycle_states, do: [:pending_launch, :launching]

  @spec terminal_lifecycle_states() :: [atom()]
  def terminal_lifecycle_states,
    do: [:launch_succeeded, :launch_failed, :registration_handoff, :expired]

  @spec cleanup_lifecycle_states() :: [atom()]
  def cleanup_lifecycle_states, do: [:pending_launch, :launching, :expired]

  @spec failure_classifications() :: [atom()]
  def failure_classifications, do: @failure_classifications

  defp validate_terminal_fields(changeset) do
    lifecycle_state = get_field(changeset, :lifecycle_state)
    failure_classification = get_field(changeset, :failure_classification)
    handoff_type = get_field(changeset, :handoff_type)

    changeset
    |> maybe_require_failure_classification(lifecycle_state, failure_classification)
    |> maybe_require_handoff_type(lifecycle_state, handoff_type)
  end

  defp maybe_require_failure_classification(changeset, :launch_failed, nil) do
    add_error(changeset, :failure_classification, "can't be blank")
  end

  defp maybe_require_failure_classification(changeset, :expired, nil) do
    add_error(changeset, :failure_classification, "can't be blank")
  end

  defp maybe_require_failure_classification(changeset, _lifecycle_state, _failure_classification),
    do: changeset

  defp maybe_require_handoff_type(changeset, :registration_handoff, nil) do
    add_error(changeset, :handoff_type, "can't be blank")
  end

  defp maybe_require_handoff_type(changeset, _lifecycle_state, _handoff_type), do: changeset
end
