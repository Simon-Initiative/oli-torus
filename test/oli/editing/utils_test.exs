defmodule Oli.Authoring.Editing.UtilsTest do
  use ExUnit.Case, async: true
  alias Oli.Authoring.Editing.Utils

  describe "diffing content for activity reference changes" do
    test "diff_activity_references/2 finds additions and removals", _ do
      content1 = [
        %{"type" => "content", children: [%{"text" => "A paragraph."}]},
        %{"type" => "activity-reference", "activity_id" => 1}
      ]

      content2 = [
        %{"type" => "content", children: [%{"text" => "A paragraph."}]},
        %{"type" => "activity-reference", "activity_id" => 2}
      ]

      {additions, deletions} = Utils.diff_activity_references(content1, content2)

      assert MapSet.size(additions) == 1
      assert MapSet.member?(additions, 2)

      assert MapSet.size(deletions) == 1
      assert MapSet.member?(deletions, 1)
    end

    test "diff_activity_references/2 finds no changes", _ do
      content1 = [
        %{"type" => "content", children: [%{"text" => "A paragraph."}]},
        %{"type" => "activity-reference", "activity_id" => 2}
      ]

      content2 = [
        %{"type" => "content", children: [%{"text" => "A paragraph."}]},
        %{"type" => "activity-reference", "activity_id" => 2}
      ]

      {additions, deletions} = Utils.diff_activity_references(content1, content2)

      assert MapSet.size(additions) == 0
      assert MapSet.size(deletions) == 0
    end

    test "diff_activity_references/2 finds several additions", _ do
      content1 = [
        %{"type" => "content", children: [%{"text" => "A paragraph."}]}
      ]

      content2 = [
        %{"type" => "content", children: [%{"text" => "A paragraph."}]},
        %{"type" => "activity-reference", "activity_id" => 1},
        %{"type" => "activity-reference", "activity_id" => 2},
        %{"type" => "activity-reference", "activity_id" => 3},
        %{"type" => "activity-reference", "activity_id" => 4}
      ]

      {additions, deletions} = Utils.diff_activity_references(content1, content2)

      assert MapSet.size(additions) == 4
      assert MapSet.size(deletions) == 0
    end
  end
end
