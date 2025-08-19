defmodule Oli.Delivery.Sections.ProgressGradeSyncLog do
  @moduledoc """
  Schema for tracking progress grade synchronization history.

  Records all attempts to synchronize student progress scores to the LMS,
  including success, failure, and retry information for audit and debugging.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Oli.Delivery.Sections.Section
  alias Oli.Accounts.User

  schema "progress_grade_sync_logs" do
    belongs_to :section, Section
    belongs_to :user, User

    field :progress_percentage, :float
    field :score, :float
    field :out_of, :float
    field :sync_status, Ecto.Enum, values: [:pending, :success, :failed]
    field :error_details, :string
    field :attempt_number, :integer

    timestamps()
  end

  @doc """
  Creates a changeset for a new sync log entry.
  """
  def changeset(sync_log, attrs) do
    sync_log
    |> cast(attrs, [
      :section_id,
      :user_id,
      :progress_percentage,
      :score,
      :out_of,
      :sync_status,
      :error_details,
      :attempt_number
    ])
    |> validate_required([
      :section_id,
      :user_id,
      :progress_percentage,
      :score,
      :out_of,
      :sync_status
    ])
    |> validate_number(:progress_percentage,
      greater_than_or_equal_to: 0.0,
      less_than_or_equal_to: 1.0
    )
    |> validate_number(:score, greater_than_or_equal_to: 0.0)
    |> validate_number(:out_of, greater_than: 0.0)
    |> validate_number(:attempt_number, greater_than: 0)
    |> validate_inclusion(:sync_status, [:pending, :success, :failed])
    |> foreign_key_constraint(:section_id)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Creates a changeset for a pending sync entry.
  """
  def pending_changeset(section_id, user_id, progress_percentage, score, out_of) do
    %__MODULE__{}
    |> changeset(%{
      section_id: section_id,
      user_id: user_id,
      progress_percentage: progress_percentage,
      score: score,
      out_of: out_of,
      sync_status: :pending,
      attempt_number: 1
    })
  end

  @doc """
  Creates a changeset for updating sync status to success.
  """
  def success_changeset(sync_log) do
    changeset(sync_log, %{sync_status: :success})
  end

  @doc """
  Creates a changeset for updating sync status to failed with error details.
  """
  def failure_changeset(sync_log, error_details, attempt_number \\ nil) do
    attrs = %{sync_status: :failed, error_details: error_details}
    attrs = if attempt_number, do: Map.put(attrs, :attempt_number, attempt_number), else: attrs

    changeset(sync_log, attrs)
  end

  @doc """
  Creates a changeset for incrementing the attempt number on retry.
  """
  def retry_changeset(sync_log) do
    current_attempt = sync_log.attempt_number || 1

    changeset(sync_log, %{
      sync_status: :pending,
      attempt_number: current_attempt + 1,
      error_details: nil
    })
  end
end
