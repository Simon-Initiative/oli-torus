defmodule Oli.Delivery.Settings.SettingsChanges do
  use Ecto.Schema

  import Ecto.Changeset

  schema "settings_changes" do
    belongs_to(:resource, Oli.Resources.Resource)
    belongs_to(:section, Oli.Delivery.Sections.Section)

    field(:user_id, :integer)
    field(:user_type, Ecto.Enum, values: [:author, :instructor])
    field(:key, :string)
    field(:new_value, :string)
    field(:old_value, :string)

    timestamps(type: :utc_datetime)
  end

  def changeset(settings_change, attrs) do
    settings_change
    |> cast(attrs, [
      :user_id,
      :section_id,
      :resource_id,
      :user_type,
      :key,
      :new_value,
      :old_value
    ])
    |> validate_required([:user_id, :section_id, :resource_id])
  end
end
