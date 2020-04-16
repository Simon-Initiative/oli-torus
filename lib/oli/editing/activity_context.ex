defmodule Oli.Editing.ActivityContext do

  @derive Jason.Encoder
  defstruct [
    :authoringScript,
    :authoringElement,
    :friendlyName,
    :description,
    :authorEmail,
    :projectSlug,
    :resourceSlug,
    :activitySlug,
    :title,
    :model,
    :objectives,
    :allObjectives,
    :previousActivity,
    :nextActivity
  ]

end
