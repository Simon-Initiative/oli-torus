defmodule Oli.PartComponents.Manifest do
  import Oli.Utils

  defstruct [
    :id,
    :friendlyName,
    :description,
    :icon,
    :author,
    :delivery,
    :authoring,
    :allowClientEvaluation,
    :global
  ]

  def parse(
        %{
          "id" => id,
          "friendlyName" => friendlyName,
          "description" => description,
          "icon" => icon,
          "author" => author,
          "delivery" => delivery,
          "authoring" => authoring
        } = json
      ) do
    %Oli.PartComponents.Manifest{
      id: id,
      friendlyName: friendlyName,
      description: description,
      icon: value_or(json["icon"], "icon-part-generic.svg"),
      author: value_or(json["author"], "Unknown"),
      delivery: Oli.Activities.ModeSpecification.parse(delivery),
      authoring: Oli.Activities.ModeSpecification.parse(authoring),
      allowClientEvaluation: value_or(json["allowClientEvaluation"], false),
      global: value_or(json["global"], false)
    }
  end
end
