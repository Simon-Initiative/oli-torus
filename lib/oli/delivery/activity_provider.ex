defmodule Oli.Delivery.ActivityProvider do

  alias Oli.Activities.Realizer
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Revision

  @doc """
  Realizes and resolves activities.
  """
  def provide(section_slug, %Revision{} = revision) do
    case Realizer.realize(revision) do
      [] -> []
      ids -> DeliveryResolver.from_resource_id(section_slug, ids)
    end
  end

end
