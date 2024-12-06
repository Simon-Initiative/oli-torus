defmodule Oli.Analytics.Datasets.Utils do

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

end
