defmodule Oli.Utils.Stagehand do
  @moduledoc """
  Stagehand is a tool for generating fake data for testing and development.

  ## Usage
  Be sure to start your development server in iex mode: `iex -S mix phx.server`

  Then you can use the following commands to generate fake data:

  ```elixir
  # Simulate enrollments for a section
  iex> Oli.Utils.Stagehand.simulate_enrollments("example_section", num_instructors: 3, num_students: 5)

  # Simulate progress for students in a section, with 80% of responses being correct
  iex> Oli.Utils.Stagehand.simulate_progress("example_section", pct_correct: 0.8)
  ```
  """

  require Logger

  import Oli.Utils.Seeder.Utils

  alias Oli.Resources.Revision
  alias Oli.Utils.Seeder
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Attempts.Core.StudentInput
  alias Oli.Delivery.Attempts.Core.PartAttempt
  alias Oli.Activities
  alias Oli.Delivery.Attempts.ActivityLifecycle.Evaluate
  alias Oli.Utils.Stagehand.SimulateProgress

  @doc """
  Simulates a typical set of enrollments for a section.
  """
  def simulate_enrollments(section_slug, opts \\ []) do
    num_instructors = Keyword.get(opts, :num_instructors, 3)
    num_students = Keyword.get(opts, :num_students, 5)

    case Sections.get_section_by_slug(section_slug) do
      nil ->
        Logger.error("Section not found: #{section_slug}")

      section ->
        map = %{}

        map =
          if num_instructors > 0 do
            map = Enum.reduce(1..num_instructors, map, fn _i, map ->
              Seeder.Section.create_and_enroll_instructor(map, section)
            end)

            Logger.info("Enrolled #{num_instructors} instructors in section #{section_slug}")

            map
          else
            map
          end

        map =
          if num_students > 0 do
            map = Enum.reduce(1..num_students, map, fn _i, map ->
              Seeder.Section.create_and_enroll_learner(map, section)
            end)

            Logger.info("Enrolled #{num_students} students in section #{section_slug}")

            map
          else
            map
          end

        map
    end
  end

  @doc """
  Simulates progress for students in a given section.

  ## Options
  * `pct_correct` - the percentage of responses that should be correct, defaults to 1.0
  * `chunk_size` - the number of students to simulate at a time, defaults to 10
  """
  def simulate_progress(section_slug, opts \\ []) do
    pct_correct = Keyword.get(opts, :pct_correct, 1.0)
    chunk_size = Keyword.get(opts, :chunk_size, 10)

    students =
      Sections.fetch_students(section_slug)
      |> Enum.map(fn student -> {student, UUID.uuid4()} end)

    section = Sections.get_section_by_slug(section_slug)
    all_pages = Sections.fetch_all_pages(section_slug)

    students
    |> Enum.chunk_every(chunk_size)
    |> Enum.map(fn chunk ->
      chunk
      |> Enum.map(fn {student, datashop_session_id} ->
        Task.async(fn ->
          SimulateProgress.simulate_student_working_through_course(
            section,
            student,
            all_pages,
            datashop_session_id,
            pct_correct
          )
        end)
      end)
      |> Task.await_many()
    end)
  end

end
