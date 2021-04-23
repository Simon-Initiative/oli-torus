defmodule Oli.PartComponents.PartComponentMapEntry do
  alias Oli.PartComponents.PartComponentRegistration

  @derive Jason.Encoder
  defstruct [
    :deliveryElement,
    :authoringElement,
    :icon,
    :description,
    :friendlyName,
    :slug,
    :globallyAvailable,
    enabledForProject: false
  ]

  def from_registration(%PartComponentRegistration{
        slug: slug,
        description: description,
        icon: icon,
        title: title,
        authoring_element: authoring_element,
        delivery_element: delivery_element,
        globally_available: globally_available
      }) do
    %Oli.PartComponents.PartComponentMapEntry{
      slug: slug,
      friendlyName: title,
      description: description,
      authoringElement: authoring_element,
      icon: icon,
      deliveryElement: delivery_element,
      globallyAvailable: globally_available,
      enabledForProject: globally_available
    }
  end
end
