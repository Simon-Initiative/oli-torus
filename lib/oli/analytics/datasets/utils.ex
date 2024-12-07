defmodule Oli.Analytics.Datasets.Utils do

  alias Oli.Repo
  import Ecto.Query

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

  def determine_ignored_student_ids(section_ids) do
    query = from(e in Oli.Delivery.Sections.Enrollment,
      join: u in Oli.Accounts.User, on: u.id == e.user_id,
      where: e.section_id in ^section_ids and u.research_opt_out == true,
      select: u.id)

    Repo.all(query)
  end

end
