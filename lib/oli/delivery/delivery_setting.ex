defmodule Oli.Delivery.DeliverySetting do
  use Ecto.Schema

  import Ecto.Changeset

  schema "delivery_settings" do
    belongs_to :user, Oli.Accounts.User
    belongs_to :section, Oli.Delivery.Sections.Section
    belongs_to :resource, Oli.Resources.Resource

    embeds_one :collab_space_config, Oli.Resources.Collaboration.CollabSpaceConfig, on_replace: :update

    timestamps(type: :utc_datetime)
  end

  def changeset(post, attrs \\ %{}) do
    post
    |> cast(attrs, [
      :user_id,
      :section_id,
      :resource_id
    ])
    |> cast_embed(:collab_space_config)
  end
end
