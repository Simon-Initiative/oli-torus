defmodule Oli.Activities.Manifest do
  import Oli.Utils

  defstruct [
    :id,
    :friendlyName,
    :petiteLabel,
    :description,
    :delivery,
    :authoring,
    :allowClientEvaluation,
    :icon,
    :global,
    :variables,
    :generatesReport,
    :activityRegistration
  ]

  def parse(
        %{
          "id" => id,
          "friendlyName" => friendlyName,
          "petiteLabel" => petiteLabel,
          "description" => description,
          "delivery" => delivery,
          "authoring" => authoring
        } = json
      ) do
    {:ok,
     %Oli.Activities.Manifest{
       id: id,
       friendlyName: friendlyName,
       petiteLabel: petiteLabel,
       description: description,
       icon: Map.get(json, "icon", "question-circle"),
       delivery: Oli.Activities.ModeSpecification.parse(delivery),
       authoring: Oli.Activities.ModeSpecification.parse(authoring),
       allowClientEvaluation: value_or(json["allowClientEvaluation"], false),
       global: false,
       variables: value_or(json["variables"], []),
       generatesReport: value_or(json["generatesReport"], false),
       activityRegistration: value_or(json["activityRegistration"], true)
     }}
  end

  def parse(_json) do
    {:error, :invalid_manifest}
  end
end
