defmodule Oli.Authoring.Editing.ResourceContext do
  @derive {Jason.Encoder, except: [:project, :previous_page, :next_page, :num_page_breaks]}
  defstruct [
    :graded,
    :authorEmail,
    :projectSlug,
    :resourceSlug,
    :title,
    :content,
    :objectives,
    :allObjectives,
    :allTags,
    :editorMap,
    :activities,
    :activityContexts,
    :resourceId,
    # these fields are not JSON encoded
    :project,
    :previous_page,
    :next_page,
    :num_page_breaks
  ]
end
