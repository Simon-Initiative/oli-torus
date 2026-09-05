defmodule Oli.Delivery.PreviousNextIndexBackfillTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.PreviousNextIndexBackfill
  alias Oli.Delivery.Sections.Section

  defp cached_index, do: %{"1" => %{"id" => "1", "level" => "1", "index" => "1"}}

  describe "run/1" do
    test "nulls previous_next_index only for sections with a non-empty unnumbered_unit_ids" do
      suppressed_section =
        insert(:section, unnumbered_unit_ids: [123], previous_next_index: cached_index())

      plain_section =
        insert(:section, unnumbered_unit_ids: [], previous_next_index: cached_index())

      already_nil_section =
        insert(:section, unnumbered_unit_ids: [456], previous_next_index: nil)

      updated_count = PreviousNextIndexBackfill.run()

      # Only the suppressed section with a real cached value counted as updated --
      # already_nil_section had nothing to null (guarded by the IS NOT NULL predicate).
      assert updated_count == 1

      assert Repo.get!(Section, suppressed_section.id).previous_next_index == nil
      assert Repo.get!(Section, plain_section.id).previous_next_index == cached_index()
      assert Repo.get!(Section, already_nil_section.id).previous_next_index == nil
    end

    test "pagination visits every matching section across multiple batches" do
      suppressed_sections =
        for _ <- 1..5 do
          insert(:section, unnumbered_unit_ids: [1], previous_next_index: cached_index())
        end

      # A batch size smaller than the fixture forces multiple pages.
      updated_count = PreviousNextIndexBackfill.run(batch_size: 2)

      assert updated_count == 5

      for section <- suppressed_sections do
        assert Repo.get!(Section, section.id).previous_next_index == nil
      end
    end

    test "is idempotent: a second run updates nothing once the first run has completed" do
      insert(:section, unnumbered_unit_ids: [1], previous_next_index: cached_index())
      insert(:section, unnumbered_unit_ids: [], previous_next_index: cached_index())

      assert PreviousNextIndexBackfill.run() == 1
      assert PreviousNextIndexBackfill.run() == 0
    end
  end
end
