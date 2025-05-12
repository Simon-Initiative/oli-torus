defmodule Oli.Activities.ActivityMapEntry do
  alias Oli.Activities.ActivityRegistration

  @derive Jason.Encoder
  defstruct [
    :id,
    :deliveryElement,
    :authoringElement,
    :icon,
    :description,
    :friendlyName,
    :petiteLabel,
    :slug,
    :globallyAvailable,
    :variables,
    :isLtiActivity,
    enabledForProject: false
  ]

  def from_registration(%ActivityRegistration{
        id: id,
        slug: slug,
        description: description,
        icon: icon,
        title: title,
        petite_label: petite_label,
        authoring_element: authoring_element,
        delivery_element: delivery_element,
        globally_available: globally_available,
        variables: variables,
        deployment_id: deployment_id
      }) do
    %Oli.Activities.ActivityMapEntry{
      id: id,
      slug: slug,
      friendlyName: title,
      description: description,
      authoringElement: authoring_element,
      petiteLabel: petite_label,
      icon: icon,
      deliveryElement: delivery_element,
      globallyAvailable: globally_available,
      enabledForProject: globally_available,
      variables: Oli.Delivery.Page.ActivityContext.build_variables_map(variables, petite_label),
      isLtiActivity: !is_nil(deployment_id)
    }
  end
end
