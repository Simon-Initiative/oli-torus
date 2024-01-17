defmodule Oli.Delivery.Settings.AutoSubmitCustodian do

  @moduledoc """
  This module is responsible for managing the auto submit jobs when assessment
  settings are changed by an instructor in the assessment settings page.
  """
  import Ecto.Query

  alias Oli.Repo
  alias Oli.Delivery.Attempts.Core.{ResourceAttempt, ResourceAccess}
  alias Oli.Delivery.Settings.StudentException
  alias Oli.Delivery.Attempts.AutoSubmit.Worker

  @doc """
  Adjusts one or more auto submit jobs for a given section, assessment, and student,
  taking into account a pending change for the due date of the assessment. Takes into account
  changing the due date to nil, which results in cancelling all auto submit jobs for this assessment.

  If the student_id is nil, then adjust all auto submit jobs for this section and assessment,
  taking into account to exclude any student exceptions.

  If the student_id is not nil, then adjust only the auto submit job for that student.

  This function must be called in the context of a outer transaction, because it
  will cancel and insert auto submit jobs in the same transaction.

  Returns {:ok, count} with count being the number of affected auto submit jobs, or
  {:error, reason} if there was a problem. Can also raise an error if the Oban.insert_all
  encounters a problem.
  """
  def adjust(section_id, assessment_id, old_date_time, new_date_time, student_id) do

    if is_nil(new_date_time) do
      cancel(section_id, assessment_id, student_id)
    else

      deadline_with_slack = Worker.add_slack(new_date_time)

      active = case student_id do
        # We are adjusting auto submit jobs for all students, driven from a change
        # to the settings of the assessment.  But we must exclude all jobs that exist
        # for a student with an exception on "end_date" that is different than the
        # date we are adjusting from.
        nil ->
          except_students = students_with_exception(section_id, assessment_id, "end_date", old_date_time)

          active_auto_submits(section_id, assessment_id, nil)
          |> where([_, ra, _], ra.user_id not in ^except_students)
          |> Repo.all()

        # We are adjusting the auto_submit job from a specific student exception
        student_id ->
          active_auto_submits(section_id, assessment_id, student_id)
          |> Repo.all()
      end

      case Enum.map(active, fn %{auto_submit_job_id: id} -> id end)
        |> cancel_jobs() do

        {:ok, count} ->

          # If Oban.insert_all fails, it raises an error, so no need to handle the
          # return value here
          results = Enum.map(active, fn %{args: args} -> Worker.new(args, scheduled_at: deadline_with_slack) end)
          |> Oban.insert_all()

          if count > 0 do
            update_job_ids(active, results)
          end

          {:ok, count}

        e ->
          e

      end

    end

  end

  @doc """
  Cancels a set of auto submit jobs for a given section, assessment, and student.
  This is called when an instructor changes the "late_submit" option of an assessment
  from "disallow" to "allow".  We need to cancel any pending auto submit jobs for
  active attempts, because if we did not, at the due date these jobs would auto submit
  when the intention is to allow the student to now keep working and submit late.
  """
  def cancel(section_id, assessment_id, nil) do

    except_students = students_with_exception(section_id, assessment_id, "late_submit", :disallow)

    active = active_auto_submits(section_id, assessment_id, nil)
    |> where([_, ra, _], ra.user_id not in ^except_students)
    |> Repo.all()

    remove_job_ids(active)

    Enum.map(active, fn %{auto_submit_job_id: id} -> id end)
    |> cancel_jobs()
  end

  def cancel(section_id, assessment_id, student_id) do
    active = active_auto_submits(section_id, assessment_id, student_id)
    |> Repo.all()

    remove_job_ids(active)

    Enum.map(active, fn %{auto_submit_job_id: id} -> id end)
    |> cancel_jobs()
  end

  # Helper to cancel a collection of jobs in a single DB statement.
  defp cancel_jobs(job_ids) do
    query = from(j in Oban.Job, where: j.id in ^job_ids)
    Oban.cancel_all_jobs(query)
  end

  # Return a query (not RUN a query) to access all pending auto submit jobs
  # for this section, assessment, and student.  If student_id is nil, then
  # return all auto submit jobs for this section and assessment. If student_id
  # is not nil, then return all auto submit jobs for just that student.
  #
  # Note that this query is not run until the Repo.all() call in the caller.
  #
  # This query is intended to be augmented with an additional "where" clause
  # to exclude students that have an exception for this assessment.
  defp active_auto_submits(section_id, assessment_id, student_id) do
    constrain_by_student =
      case student_id do
        nil ->
          dynamic([_r, _ra], true)

        _ ->
          dynamic([r, ra], ra.user_id == ^student_id)
      end

    ResourceAttempt
    |> join(:left, [r], ra in ResourceAccess, on: r.resource_access_id == ra.id)
    |> join(:left, [r, _], job in "oban_jobs", on: r.auto_submit_job_id == job.id)
    |> where([_, ra, _], ra.resource_id == ^assessment_id and ra.section_id == ^section_id)
    |> where(^constrain_by_student)
    |> where([r, _, _], not is_nil(r.auto_submit_job_id))
    |> select([r, ra, job], %{
      args: job.args,
      attempt_id: r.id,
      auto_submit_job_id: r.auto_submit_job_id
    })

  end

  # Find all student ids that have an existing exception for the same assessment,
  # where a key has a different (non nil) value than the one passed in.  We use
  # this to determine which students have a different end_date or a different
  # late_submit exception
  defp students_with_exception(section_id, assessment_id, key, value) do
    StudentException
    |> where(section_id: ^section_id, resource_id: ^assessment_id)
    |> where([se], field(se, ^String.to_existing_atom(key)) != ^value and not is_nil(field(se, ^String.to_existing_atom(key))))
    |> select([se], se.user_id)
    |> Repo.all()
  end

  # bulk change the auto_submit_job_id for a set of resource attempts from the
  # old job id to the newly scheduled job id
  defp update_job_ids(entries, new_jobs) do

    {values, params, _} = Enum.zip(entries, new_jobs)
    |> Enum.reduce({[], [], 0}, fn {%{attempt_id: attempt_id}, %{id: job_id}}, {values, params, i} ->
        {
          values ++ ["($#{i + 1}::bigint, $#{i + 2}::bigint)"],
          params ++ [attempt_id, job_id],
          i + 2
        }
      end)

      values = Enum.join(values, ",")

    sql = """
      UPDATE resource_attempts
      SET
        auto_submit_job_id = batch_values.auto_submit_job_id,
        updated_at = NOW()
      FROM (
          VALUES
          #{values}
      ) AS batch_values (id, auto_submit_job_id)
      WHERE resource_attempts.id = batch_values.id
    """

    {:ok, _} = Ecto.Adapters.SQL.query(Oli.Repo, sql, params)

  end

  # Clear the auto_submit_job_id for a set of resource attempts
  defp remove_job_ids(entries) do
    ids = Enum.map(entries, fn %{attempt_id: id} -> id end)

    query = from(r in ResourceAttempt, where: r.id in ^ids)
    Oli.Repo.update_all(query, set: [auto_submit_job_id: nil])
  end

end
