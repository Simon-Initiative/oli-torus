defmodule Oli.Delivery.Attempts.PageLifecycle do
  import Ecto.Query, warn: false

  @moduledoc """
  Façade module providing a uniform interface to initiate page attempt state
  transitions and to access their state.
  """

  alias Oli.Repo
  use Appsignal.Instrumentation.Decorators
  import Oli.Delivery.Attempts.Core
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Snapshots
  alias Oli.Resources.Revision
  alias Oli.Publishing.DeliveryResolver
  alias Oli.Publishing

  alias Oli.Delivery.Attempts.Core.{
    ResourceAccess,
    ResourceAttempt
  }

  alias Oli.Delivery.Attempts.PageLifecycle.{
    VisitContext,
    FinalizationContext,
    FinalizationSummary,
    HistorySummary,
    AttemptState,
    ReviewContext
  }

  require Logger

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
  @decorate transaction_event("PageLifeCycle: start")
  def start(
        revision_slug,
        section_slug,
        datashop_session_id,
        user,
        effective_settings,
        activity_provider
      ) do
    Repo.transaction(fn ->
      Repo.query!("set transaction isolation level SERIALIZABLE;")

      case DeliveryResolver.from_revision_slug(section_slug, revision_slug) do
        nil ->
          Repo.rollback({:not_found})

        page_revision ->
          latest_resource_attempt =
            get_latest_resource_attempt(page_revision.resource_id, section_slug, user.id)

          publication_id =
            Publishing.get_publication_id_for_resource(section_slug, page_revision.resource_id)

          context = %VisitContext{
            publication_id: publication_id,
            blacklisted_activity_ids: [],
            latest_resource_attempt: latest_resource_attempt,
            page_revision: page_revision,
            section_slug: section_slug,
            user: user,
            audience_role: Oli.Delivery.Audience.audience_role(user, section_slug),
            datashop_session_id: datashop_session_id,
            activity_provider: activity_provider,
            effective_settings: effective_settings
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
  Attempt to visit a page to either resume an existing or start a new attempt.maybe_improper_list(

  Depending on the state of the attempts and other constraints
  regarding the page and user, returns one of:

  If a resource attempt is in progress, returns a tuple of the form:

  `{:ok, {:in_progress, %AttemptState{}}}`

  If a resource attempt is in progress and the revision of the resource pertaining to that attempt
  has changed compared to the supplied page_revision, returns a tuple of the form:

  `{:ok, {:revised, %AttemptState{}}}`

  If the attempt has not started, and must be started manually, returns a tuple of the form:

  `{:ok, {:not_started, %HistorySummary{}}}`

  It also updates the latest visited page for the user in the section.
  """
  @spec visit(Revision.t(), String.t(), String.t(), User.t(), any, any) ::
          {:ok, {:in_progress | :revised, AttemptState.t()}}
          | {:ok, {:not_started, HistorySummary.t()}}
          | {:error, any}
  @decorate transaction_event("PageLifeCycle: visit")
  def visit(
        page_revision,
        section_slug,
        datashop_session_id,
        user,
        effective_settings,
        activity_provider
      ) do
    Repo.transaction(fn ->

      # If this should somehow fail, it should not affect the overall transaction
      # and block the ability to view the page
      update_latest_visited_page(section_slug, user.id, page_revision.resource_id)

      {graded, latest_resource_attempt} =
        Appsignal.instrument("PageLifeCycle: get_latest_resource_attempt", fn ->
          get_latest_resource_attempt(page_revision.resource_id, section_slug, user.id)
          |> handle_type_transitions(page_revision)
        end)

      publication_id =
        Publishing.get_publication_id_for_resource(section_slug, page_revision.resource_id)

      context = %VisitContext{
        publication_id: publication_id,
        blacklisted_activity_ids: [],
        latest_resource_attempt: latest_resource_attempt,
        page_revision: page_revision,
        section_slug: section_slug,
        user: user,
        audience_role: Oli.Delivery.Audience.audience_role(user, section_slug),
        datashop_session_id: datashop_session_id,
        activity_provider: activity_provider,
        effective_settings: effective_settings
      }

      impl = determine_page_impl(graded)

      case impl.visit(context) do
        {:ok, results} -> results
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  @decorate transaction_event("PageLifeCycle: update_latest_visited_page")
  defp update_latest_visited_page(section_slug, user_id, resource_id) do
    case Sections.get_enrollment(section_slug, user_id, filter_by_status: false) do
      nil ->
        {:error, :not_enrolled}

      enrollment ->
        Sections.update_enrollment(%{most_recently_visited_resource_id: resource_id})
    end
  end

  @doc """
  Reviews an attempt for a page.

  If the resource attempt is in progress, returns a tuple of the form:

  `{:ok, {:in_progress, %AttemptState{}}}`

  If the resource attempt has been finalized, returns a tuple of the form:

  `{:ok, {:finalized, %AttemptState{}}}`

  If the resource attempt guid is not found returns:

  `{:error, {:not_found}}`
  """
  @decorate transaction_event("PageLifeCycle: review")
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

  `{:ok, %FinalizationSummary{}}`

  If the resource attempt has already been finalized:

  `{:error, {:already_submitted}}`
  """
  @decorate transaction_event("PageLifeCycle: finalize")
  def finalize(section_slug, resource_attempt_guid, datashop_session_id) do
    result =
      Repo.transaction(fn _ ->
        case get_resource_attempt_by(attempt_guid: resource_attempt_guid) do
          nil ->
            Repo.rollback({:not_found})

          resource_attempt ->
            resource_access = Oli.Repo.get(ResourceAccess, resource_attempt.resource_access_id)

            context = %FinalizationContext{
              resource_attempt: resource_attempt,
              section_slug: section_slug,
              datashop_session_id: datashop_session_id,
              effective_settings:
                Oli.Delivery.Settings.get_combined_settings(
                  resource_attempt.revision,
                  resource_access.section_id,
                  resource_access.user_id
                )
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
         graded: graded,
         part_attempt_guids: part_attempt_guids
       } = finalization_summary} ->
        if graded do
          Snapshots.queue_or_create_snapshot(part_attempt_guids, section_slug)
        end

        {:ok, finalization_summary}

      e ->
        Logger.error("Failed to finalize attempt: #{inspect(e)}")
        e
    end
  end

  defp determine_page_impl(graded) do
    case graded do
      true -> Oli.Delivery.Attempts.PageLifecycle.Graded
      _ -> Oli.Delivery.Attempts.PageLifecycle.Ungraded
    end
  end

  @doc """
  Determines whether a particular user can access the resource attempt represented by
  its attempt guid.  A user can access a resource attempt if that user is either an
  instructor enrolled in that section, or the student that originated the attempt.
  """
  @decorate transaction_event("PageLifeCycle: can_access_attempt")
  def can_access_attempt?(resource_attempt_guid, %User{id: user_id} = user, %Section{
        slug: section_slug,
        id: section_id
      }) do
    case Repo.one(
           from(attempt in ResourceAttempt,
             join: access in ResourceAccess,
             on: access.id == attempt.resource_access_id,
             where: attempt.attempt_guid == ^resource_attempt_guid,
             select: access
           )
         ) do
      %ResourceAccess{user_id: ^user_id, section_id: ^section_id} -> true
      nil -> false
      _ -> Oli.Delivery.Sections.has_instructor_role?(user, section_slug)
    end
  end

  # We cannot simply look at the current revision to know if this is a graded page or not, as
  # the author may have toggled that and republished after a student started an attempt.  To determine the graded status
  #  correctly, and to account for graded <-> ungraded transitions properly we must:
  #
  # 1. Use the current revision if no resource attempt is present, or if the current revision is set to "graded"
  # 2. Otherwise return "graded" value of the resource attempt revision.
  @decorate transaction_event("PageLifeCycle: handle_type_transitions")
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
        if resource_attempt.lifecycle_state == :active do
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
        #     -There may be some historical “ungraded” attempts, finalize all of them to provide a clean slate for the graded attempts
        #

        if resource_attempt.lifecycle_state == :active do
          # There is an open ungraded attempt that we need to finalize to allow the student
          # to start a new one in this graded context
          {:ok, updated_attempt} =
            update_resource_attempt(resource_attempt, %{
              score: 0,
              out_of: 0,
              date_evaluated: DateTime.utc_now(),
              date_submitted: DateTime.utc_now(),
              lifecycle_state: :evaluated
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
