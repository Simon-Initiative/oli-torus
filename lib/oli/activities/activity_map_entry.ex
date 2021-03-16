defmodule Oli.Activities.ActivityMapEntry do

  alias Oli.Activities.ActivityRegistration

  @derive Jason.Encoder
  defstruct [:deliveryElement, :authoringElement, :icon, :description, :friendlyName, :slug, :globallyAvailable,
    enabledForProject: false]

  def from_registration(%ActivityRegistration{slug: slug, description: description, icon: icon, title: title,
    authoring_element: authoring_element, delivery_element: delivery_element, globally_available: globally_available}) do
    %Oli.Activities.ActivityMapEntry{slug: slug, friendlyName: title, description: description,
      authoringElement: authoring_element, icon: icon, deliveryElement: delivery_element,
      globallyAvailable: globally_available, enabledForProject: globally_available}
  end

end

