defmodule Oli.Authoring.IngestTest do

  alias Oli.Authoring.Ingest
  use Oli.DataCase

  describe "course project ingest" do

    setup do
      Oli.Seeder.base_project_with_resource2()
    end

    test "ingest/1 processes the digest", %{author: author} do

      {:ok, project} = Ingest.ingest("./test/oli/authoring/course.zip", author)

    end

  end

end
