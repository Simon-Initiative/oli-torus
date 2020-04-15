defmodule Oli.Activities.Manifest do

  defstruct [:id, :friendlyName, :description, :delivery, :authoring]

  def parse(%{"id" => id, "friendlyName" => friendlyName, "description" => description, "delivery" => delivery, "authoring" => authoring }) do
    %Oli.Activities.Manifest{
      id: id,
      friendlyName: friendlyName,
      description: description,
      delivery: Oli.Activities.ModeSpecification.parse(delivery),
      authoring: Oli.Activities.ModeSpecification.parse(authoring)}
  end

end
