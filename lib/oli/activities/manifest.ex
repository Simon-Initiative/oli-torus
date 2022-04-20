defmodule Oli.Activities.Manifest do
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
    {:ok, %Oli.Activities.Manifest{
      id: id,
      friendlyName: friendlyName,
      description: description,
      delivery: Oli.Activities.ModeSpecification.parse(delivery),
      authoring: Oli.Activities.ModeSpecification.parse(authoring),
      allowClientEvaluation: value_or(json["allowClientEvaluation"], false),
      global: false
    }}
  end

  def parse(_json) do
    {:error, :invalid_manifest}
  end
end
