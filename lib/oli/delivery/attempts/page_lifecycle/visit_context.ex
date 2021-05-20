defmodule Oli.Delivery.Attempts.PageLifecycle.VisitContext do
  @moduledoc """
  A context for visiting a page.

  latest_resource_attempt - The previous resource attempt, nil if there was no previous attempt
  page_revision - The current revision for the page
  section_slug - Slug identifier for the course section
  user_id - The current user id
  activity_provider - A function that takes a section slug and page revision and produces a set of
     activity revisions

  """

  @enforce_keys [
    :latest_resource_attempt,
    :page_revision,
    :section_slug,
    :user_id,
    :activity_provider
  ]

  defstruct [
    :latest_resource_attempt,
    :page_revision,
    :section_slug,
    :user_id,
    :activity_provider
  ]

  @type t() :: %__MODULE__{
          latest_resource_attempt: %Oli.Delivery.Attempts.Core.ResourceAttempt{} | nil,
          page_revision: %Oli.Resources.Revision{},
          section_slug: String.t(),
          user_id: integer,
          activity_provider: any()
        }
end
