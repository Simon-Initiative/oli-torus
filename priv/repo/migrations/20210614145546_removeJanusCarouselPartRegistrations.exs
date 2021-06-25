defmodule Oli.Repo.Migrations.RemoveJanusCarousel do
  use Ecto.Migration

  import Ecto.Query, warn: false

  def change do
    flush()

    from(p in "part_component_registrations",
      where: delivery_element = 'janus-carousel'
    )
    |> Oli.Repo.update_all(set: [slug:"janus_image_carousel",
    delivery_element: "janus-image-carousel",
    authoring_element: "janus-image-carousel",
    authoring_script:"janus_image_carousel_authoring.js",
    delivery_script:"janus_image_carousel_delivery.js"])
  end
end
