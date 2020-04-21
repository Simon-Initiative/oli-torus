defmodule Oli.Authoring.Editing.SiblingActivity do

  @derive Jason.Encoder
  defstruct [
    :friendlyName,
    :title,
    :activitySlug,
  ]

end

