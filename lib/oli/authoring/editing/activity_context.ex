defmodule Oli.Authoring.Editing.ActivityContext do
  @derive Jason.Encoder
  defstruct [
    :authoringScript,
    :authoringElement,
    :friendlyName,
    :description,
    :authorEmail,
    :projectSlug,
    :resourceId,
    :resourceSlug,
    :resourceTitle,
    :activityId,
    :activitySlug,
    :title,
    :model,
    :objectives,
    :allObjectives,
    :typeSlug
  ]
end
