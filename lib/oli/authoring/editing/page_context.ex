defmodule Oli.Authoring.Editing.ResourceContext do
  @derive {Jason.Encoder, except: [:project, :previous_page, :next_page]}
  defstruct [
    :graded,
    :authorEmail,
    :projectSlug,
    :resourceSlug,
    :title,
    :content,
    :objectives,
    :allObjectives,
    :editorMap,
    :activities,

    # these fields are not JSON encoded
    :project,
    :previous_page,
    :next_page
  ]
end
