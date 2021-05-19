defmodule Oli.Delivery.Attempts.PageLifecycle do
  import Ecto.Query, warn: false

  alias Oli.Repo

  import Oli.Delivery.Attempts.Core

  alias Oli.Delivery.Snapshots
  alias Oli.Resources.Revision
  alias Oli.Publishing.DeliveryResolver

  alias Oli.Delivery.Attempts.PageLifecycle.{
    VisitContext,
    FinalizationContext,
    FinalizationSummary,
    HistorySummary,
    AttemptState,
    ReviewContext
  }

  @doc """
  Create a new resource attempt in an active state for the given page revision slug
  in the specified section and for a specific user.

  On success returns:
  `{:ok, %AttemptState{}}`

  Possible failure returns are:
  `{:error, {:not_found}}` if the revision slug cannot be resolved
  `{:error, {:active_attempt_present}}` if an active resource attempt is present
  `{:error, {:no_more_attempts}}` if no more attempts are present

  """
  def start(revision_slug, section_slug, user_id, activity_provider) do
    Repo.transaction(fn ->
      case DeliveryResolver.from_revision_slug(section_slug, revision_slug) do
        nil ->
          Repo.rollback({:not_found})

        page_revision ->
          latest_resource_attempt =
            get_latest_resource_attempt(page_revision.resource_id, section_slug, user_id)

          context = %VisitContext{
            latest_resource_attempt: latest_resource_attempt,
            page_revision: page_revision,
            section_slug: section_slug,
            user_id: user_id,
            activity_provider: activity_provider
          }

          impl = determine_page_impl(page_revision.graded)

          case impl.start(context) do
            {:ok, results} -> results
            {:error, error} -> Repo.rollback(error)
          end
      end
    end)
  end

  @doc """
  Attempt to visit a page, and depending on the state of the attempts and other contraints
  regarding the page and user, return one of:

  If a resource attempt is in progress, returns a tuple of the form:

  `{:ok, {:in_progress, %AttemptState{}}}`

  If a resource attempt is in progress and the revision of the resource pertaining to that attempt
  has changed compared to the supplied resource_revision, returns a tuple of the form:

  `{:ok, {:revised, %AttemptState{}}}`

  If the attempt has not started, and must be done manually, returns a tuple of the form:

  `{:ok, {:not_started, %HistorySummary{}}}`
  """
  @spec visit(%Revision{}, String.t(), number(), any) ::
          {:ok, {:in_progress | :revised, %AttemptState{}}}
          | {:ok, {:not_started, %HistorySummary{}}}
          | {:error, any}
  def visit(
        page_revision,
        section_slug,
        user_id,
        activity_provider
      ) do
    Repo.transaction(fn ->
      {graded, latest_resource_attempt} =
        get_latest_resource_attempt(page_revision.resource_id, section_slug, user_id)
        |> handle_type_transitions(page_revision)

      context = %VisitContext{
        latest_resource_attempt: latest_resource_attempt,
        page_revision: page_revision,
        section_slug: section_slug,
        user_id: user_id,
        activity_provider: activity_provider
      }

      impl = determine_page_impl(graded)

      case impl.visit(context) do
        {:ok, results} -> results
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  @doc """
  Reviews an attempt for a page

  If the resource attempt is in progress, returns a tuple of the form:

  `{:ok, {:in_progress, %AttemptState{}}}`

  If the resource attempt has been finalized, returns a tuple of the form:

  `{:ok, {:finalized, %AttemptState{}}}`
  """
  def review(resource_attempt_guid) do
    Repo.transaction(fn ->
      case get_resource_attempt_by(attempt_guid: resource_attempt_guid) do
        nil ->
          Repo.rollback({:not_found})

        resource_attempt ->
          context = %ReviewContext{
            resource_attempt: resource_attempt
          }

          impl = determine_page_impl(resource_attempt.revision.graded)

          case impl.review(context) do
            {:ok, results} -> results
            {:error, error} -> Repo.rollback(error)
          end
      end
    end)
  end

  @doc """
  Finalizes an attempt for a page.

  If the resource attempt is successfully finalized returns:

  `{:ok, %ResourceAccess{}}`

  If the resource attempt has already been finalized:

  `{:error, {:already_submitted}}`
  """
  def finalize(section_slug, resource_attempt_guid) do
    result =
      Repo.transaction(fn _ ->
        case get_resource_attempt_by(attempt_guid: resource_attempt_guid) do
          nil ->
            Repo.rollback({:not_found})

          resource_attempt ->
            context = %FinalizationContext{
              resource_attempt: resource_attempt,
              section_slug: section_slug
            }

            impl = determine_page_impl(resource_attempt.revision.graded)

            case impl.finalize(context) do
              {:ok, results} -> results
              {:error, error} -> Repo.rollback(error)
            end
        end
      end)

    case result do
      {:ok,
       %FinalizationSummary{
         resource_access: resource_access,
         part_attempt_guids: part_attempt_guids
       }} ->
        Snapshots.queue_or_create_snapshot(part_attempt_guids, section_slug)
        {:ok, resource_access}

      e ->
        e
    end
  end

  defp determine_page_impl(graded) do
    case graded do
      true -> Oli.Delivery.Attempts.PageLifecycle.Graded
      _ -> Oli.Delivery.Attempts.PageLifecycle.Ungraded
    end
  end

  # We cannot simply look at the current revision to know if this is a graded page or not, as
  # the author may have toggled that and republished after a student started an attempt.  To determine the graded status
  #  correctly, and to account for graded <-> ungraded transitions properly we must:
  #
  # 1. Use the current revision if no resource attempt is present, or if the current revision is set to "graded"
  # 2. Otherwise return "graded" value of the resource attempt revision.
  defp handle_type_transitions(resource_attempt, resource_revision) do
    if is_nil(resource_attempt) || resource_attempt.revision.graded === resource_revision.graded do
      # There is no latest attempt, or the latest attempt revision's graded status doesn't differ from the current revisions
      {resource_revision.graded, resource_attempt}
    else
      # The revision on the latest attempt and the revision on current are different.

      # If it was graded and is now ungraded:
      #     -Allow an "open" graded latest attempt to resume
      #     -If no open graded attempts, we proceed in a way that allows the student to access this as ungraded

      if resource_attempt.revision.graded == true do
        if is_nil(resource_attempt.date_evaluated) do
          # Returning true here allows their active graded attempt to continue
          {true, resource_attempt}
        else
          # This will allow the beginning of a new ungraded attempt
          {false, resource_attempt}
        end
      else
        # We want to handle:
        #
        # 1. If it was ungraded and now is graded:
        #     -There may be some historical “ungraded” attempts, delete all of them to provide a clean slate for the graded attempts
        #

        if is_nil(resource_attempt.date_evaluated) do
          # There is an open ungraded attempt that we need to finalize to allow the student
          # to start a new one in this graded context
          {:ok, updated_attempt} =
            update_resource_attempt(resource_attempt, %{
              score: 0,
              out_of: 0,
              date_evaluated: DateTime.utc_now()
            })

          {true, updated_attempt}
        else
          # This will allow the beginning of a new ungraded attempt
          {true, resource_attempt}
        end
      end
    end
  end
end
