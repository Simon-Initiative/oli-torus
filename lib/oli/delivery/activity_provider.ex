defmodule Oli.Delivery.ActivityProvider do

  alias Oli.Activities.Realizer
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Resources.Revision

  @doc """
  Realizes and resolves activities.
  """
  def provide(context_id, %Revision{} = revision) do
    case Realizer.realize(revision) do
      [] -> []
      ids -> DeliveryResolver.from_resource_id(context_id, ids)
    end
  end

end
