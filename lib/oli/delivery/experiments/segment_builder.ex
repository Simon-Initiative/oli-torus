defmodule Oli.Delivery.Experiments.SegmentBuilder do

  @doc """
  Builds the JSON representation of an Upgrade segment, which (after downloaded) can be
  used to import the segment into Upgrade.
  """
  def build(%Oli.Authoring.Course.Project{slug: slug, title: title}) do

    now = DateTime.utc_now() |> DateTime.to_string()

    %{
      "createdAt" => now,
      "updatedAt" => now,
      "versionNumber" => 1,
      "id" => UUID.uuid4(),
      "name" => slug,
      "description" => title,
      "context" => "add",
      "type" => "public",
      "individualForSegment" => [],
      "groupForSegment" => [
        %{
          "createdAt" => now,
          "updatedAt" => now,
          "versionNumber" => 1,
          "groupId" => slug,
          "type" => "add-group1"
        }
      ],
      "subSegments" => []
    }
  end

end
