defmodule Oli.Delivery.Attempts.ReviewPolicy do
  @moduledoc """
  Shared policy for deciding whether a user can review a finalized page attempt.
  """

  alias Oli.Delivery.Attempts.PageLifecycle
  alias Oli.Delivery.Page.PageContext
  alias Oli.Delivery.Sections

  def allowed?(
        attempt_guid,
        current_user,
        section,
        %PageContext{} = page_context,
        opts \\ []
      ) do
    cond do
      Keyword.get(opts, :is_admin?, false) ->
        true

      Sections.has_instructor_role?(current_user, section.slug) ->
        true

      true ->
        PageLifecycle.can_access_attempt?(attempt_guid, current_user, section) &&
          review_submission_allowed?(page_context)
    end
  end

  def review_submission_allowed?(%PageContext{effective_settings: effective_settings}),
    do: review_submission_allowed?(effective_settings)

  def review_submission_allowed?(%{review_submission: :allow}), do: true
  def review_submission_allowed?(_), do: false
end
