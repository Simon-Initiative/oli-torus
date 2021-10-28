defmodule Oli.Delivery.Attempts.Core.ActivityAttemptSaveFile do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_attempt_save_files" do
    field(:attempt_guid, :string)
    field(:user_id, :string)
    field(:attempt_number, :integer)
    field(:file_name, :string)
    field(:file_guid, :string)
    field(:content, :string)
    field(:mime_type, :string)
    field(:byte_encoding, :string)
    field(:activity_type, :string)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [
      :attempt_guid,
      :user_id,
      :attempt_number,
      :file_name,
      :file_guid,
      :content,
      :mime_type,
      :byte_encoding,
      :activity_type
    ])
    |> validate_required([
      :attempt_guid,
      :user_id,
      :file_name,
      :file_guid,
      :content,
      :mime_type,
      :activity_type
    ])
  end
end
