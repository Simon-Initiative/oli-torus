defmodule Oli.Delivery.Sections.SectionResourceMigrationTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections.SectionResourceMigration

  describe "requires_migration?/1" do
    test "returns true when section has section resources not yet migrated" do
      section = insert(:section)

      insert(:section_resource, section: section, graded: nil)

      assert SectionResourceMigration.requires_migration?(section.id)
    end

    test "returns false when section has all section resources migrated" do
      section = insert(:section)

      insert(:section_resource, section: section, graded: true)
      insert(:section_resource, section: section, graded: false)

      refute SectionResourceMigration.requires_migration?(section.id)
    end

    test "returns true when section has mix of resources migrated and not yet migrated" do
      section = insert(:section)

      insert(:section_resource, section: section, graded: true)
      insert(:section_resource, section: section, graded: nil)

      assert SectionResourceMigration.requires_migration?(section.id)
    end
  end
end
