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
    :publication_id,
    :blacklisted_activity_ids,
    :latest_resource_attempt,
    :page_revision,
    :section_slug,
    :user,
    :audience_role,
    :datashop_session_id,
    :activity_provider,
    :effective_settings
  ]

  defstruct [
    :publication_id,
    :blacklisted_activity_ids,
    :latest_resource_attempt,
    :page_revision,
    :section_slug,
    :user,
    :audience_role,
    :datashop_session_id,
    :activity_provider,
    :effective_settings
  ]

  @type t() :: %__MODULE__{
          publication_id: integer(),
          blacklisted_activity_ids: list(),
          latest_resource_attempt: %Oli.Delivery.Attempts.Core.ResourceAttempt{} | nil,
          page_revision: %Oli.Resources.Revision{},
          section_slug: String.t(),
          user: Oli.Accounts.User.t() | Oli.Accounts.Author.t(),
          audience_role: :student | :instructor,
          datashop_session_id: String.t(),
          activity_provider: any(),
          effective_settings: Oli.Delivery.Settings.Combined.t()
        }
end
