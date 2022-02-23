defmodule Oli.Notifications.SystemMessage do
  use Ecto.Schema
  import Ecto.Changeset
  import Oli.Utils

  @string_field_limit 140

  @derive {Jason.Encoder, only: [:id, :message, :active, :start, :end]}

  schema "system_messages" do
    field :message, :string
    field :active, :boolean
    field :start, :utc_datetime
    field :end, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(system_message, attrs \\ %{}) do
    system_message
    |> cast(attrs, [:message, :active, :start, :end])
    |> validate_required([:message])
    |> validate_length(:message, max: @string_field_limit)
    |> validate_dates_consistency(:start, :end)
  end
end
