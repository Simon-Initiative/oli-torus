defmodule Oli.Analytics.XAPI.PendingUpload do
  @moduledoc """
  This schema represents statement bundles that had to be written to the DB
  because either they failed to upload, or they were drained from the queue during
  a shutdown event.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "pending_uploads" do
    field(:reason, Ecto.Enum, values: [:failed, :drained])
    field(:bundle, :map)
    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [
      :reason,
      :bundle
    ])
    |> validate_required([:reason, :bundle])
  end
end
