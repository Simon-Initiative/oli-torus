defmodule Oli.PartComponents.Manifest do
  import Oli.Utils

  defstruct [
    :id,
    :friendlyName,
    :description,
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
          "delivery" => delivery,
          "authoring" => authoring
        } = json
      ) do
    %Oli.PartComponents.Manifest{
      id: id,
      friendlyName: friendlyName,
      description: description,
      delivery: Oli.Activities.ModeSpecification.parse(delivery),
      authoring: Oli.Activities.ModeSpecification.parse(authoring),
      allowClientEvaluation: value_or(json["allowClientEvaluation"], false),
      global: value_or(json["global"], false)
    }
  end
end
