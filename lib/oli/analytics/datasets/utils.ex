defmodule Oli.Analytics.Datasets.Utils do

  alias Oli.Repo
  import Ecto.Query
  alias Lti_1p3.Tool.ContextRoles

  @student_role ContextRoles.get_role(:context_learner).id

  @doc """
  Determines the chunk size for a dataset job based on the fields that are excluded from the dataset.
  The rationale here is that we can choose larger chunk sizes when certain, large content fields are
  excluded from the dataset, as the total size of the chunk will be smaller.
  """
  def determine_chunk_size(excluded_fields) do

    excluded_set = MapSet.new(excluded_fields)

    # Count the number of "large content" fields that are included
    large_content_included_count = Enum.filter([:response, :feedback, :hints], fn field -> !MapSet.member?(excluded_set, field) end)
    |> Enum.count()

    # Set the chunk size based on the number of large content fields included
    # which attempts to balace the total size of a chunk across all dataset jobs
    case large_content_included_count do
      0 -> 50_000
      1 -> 25_000
      2 -> 15_000
      3 -> 10_000
    end
  end

  @doc """
  Returns a list of user ids that should be ignored for dataset creation. These include
  users that have opted out of research and users that are not students in the section.
  """
  def determine_ignored_student_ids(section_ids) do
    query = from(e in Oli.Delivery.Sections.Enrollment,
      join: u in Oli.Accounts.User, on: u.id == e.user_id,
      join: ecr in Oli.Delivery.Sections.EnrollmentContextRole, on: ecr.enrollment_id == e.id,
      where: e.section_id in ^section_ids and (u.research_opt_out == true or ecr.role != @student_role),
      select: u.id)

    Repo.all(query)
  end

end
