defmodule Oli.Authoring.Editing.ActivityContext do

  @derive Jason.Encoder
  defstruct [
    :authoringScript,
    :authoringElement,
    :friendlyName,
    :description,
    :authorEmail,
    :projectSlug,
    :resourceSlug,
    :resourceTitle,
    :activitySlug,
    :title,
    :model,
    :objectives,
    :allObjectives,
    :previousActivity,
    :nextActivity
  ]

end
