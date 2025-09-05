defmodule Oli.TagsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Tags
  alias Oli.Tags.{Tag, ProjectTag, SectionTag}

  describe "create_tag/1" do
    test "with valid data creates a tag" do
      attrs = %{name: "Biology"}

      assert {:ok, %Tag{} = tag} = Tags.create_tag(attrs)
      assert tag.name == "Biology"
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Tags.create_tag(%{name: ""})
    end

    test "enforces unique tag names" do
      attrs = %{name: "Biology"}
      assert {:ok, %Tag{}} = Tags.create_tag(attrs)
      assert {:error, %Ecto.Changeset{}} = Tags.create_tag(%{name: "Biology"})
    end
  end

  describe "get_tag_by_name/1" do
    test "returns the tag with given name" do
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})

      assert Tags.get_tag_by_name("Biology") == tag
    end

    test "returns nil when tag doesn't exist" do
      assert Tags.get_tag_by_name("nonexistent") == nil
    end
  end

  describe "list_tags/1" do
    test "returns all tags" do
      {:ok, _tag1} = Tags.create_tag(%{name: "Biology"})
      {:ok, _tag2} = Tags.create_tag(%{name: "Chemistry"})

      tags = Tags.list_tags()
      assert length(tags) == 2
    end

    test "returns empty list when no tags exist" do
      tags = Tags.list_tags()
      assert tags == []
    end

    test "filters tags by search term" do
      {:ok, _tag1} = Tags.create_tag(%{name: "Biology"})
      {:ok, _tag2} = Tags.create_tag(%{name: "Chemistry"})
      {:ok, _tag3} = Tags.create_tag(%{name: "Biochemistry"})

      tags = Tags.list_tags(%{search: "bio"})
      tag_names = Enum.map(tags, & &1.name)
      assert "Biology" in tag_names
      assert "Biochemistry" in tag_names
      refute "Chemistry" in tag_names
    end

    test "limits results" do
      {:ok, _tag1} = Tags.create_tag(%{name: "A"})
      {:ok, _tag2} = Tags.create_tag(%{name: "B"})
      {:ok, _tag3} = Tags.create_tag(%{name: "C"})

      tags = Tags.list_tags(%{limit: 2})
      assert length(tags) == 2
    end

    test "offsets results" do
      {:ok, _tag1} = Tags.create_tag(%{name: "A"})
      {:ok, _tag2} = Tags.create_tag(%{name: "B"})

      tags = Tags.list_tags(%{offset: 1})
      assert length(tags) == 1
    end

    test "returns tags in alphabetical order" do
      {:ok, _tag1} = Tags.create_tag(%{name: "Zebra"})
      {:ok, _tag2} = Tags.create_tag(%{name: "Apple"})

      tags = Tags.list_tags()
      assert hd(tags).name == "Apple"
    end
  end

  describe "associate_tag_with_project/2" do
    test "associates tag with project using structs" do
      project = insert(:project)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})

      assert {:ok, %ProjectTag{}} = Tags.associate_tag_with_project(project, tag)
    end

    test "associates tag with project using IDs" do
      project = insert(:project)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})

      assert {:ok, %ProjectTag{}} = Tags.associate_tag_with_project(project.id, tag.id)
    end

    test "handles non-existent project" do
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})

      assert {:error, :project_not_found} = Tags.associate_tag_with_project(999_999, tag)
    end

    test "handles non-existent tag" do
      project = insert(:project)

      assert {:error, :tag_not_found} = Tags.associate_tag_with_project(project, 999_999)
    end

    test "handles duplicate associations" do
      project = insert(:project)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})

      # First association should succeed
      assert {:ok, %ProjectTag{}} = Tags.associate_tag_with_project(project, tag)

      # Second association should return already_exists error
      assert {:error, :already_exists} = Tags.associate_tag_with_project(project, tag)
    end
  end

  describe "associate_tag_with_section/2" do
    test "associates tag with section" do
      section = insert(:section)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})

      assert {:ok, %SectionTag{}} = Tags.associate_tag_with_section(section, tag)
    end

    test "associates tag with product (blueprint section)" do
      product = insert(:section, %{type: :blueprint})
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})

      assert {:ok, %SectionTag{}} = Tags.associate_tag_with_section(product, tag)
    end

    test "associates tag with section using IDs" do
      section = insert(:section)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})

      assert {:ok, %SectionTag{}} = Tags.associate_tag_with_section(section.id, tag.id)
    end

    test "handles non-existent section" do
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})

      assert {:error, :section_not_found} = Tags.associate_tag_with_section(999_999, tag)
    end

    test "handles non-existent tag" do
      section = insert(:section)

      assert {:error, :tag_not_found} = Tags.associate_tag_with_section(section, 999_999)
    end
  end

  describe "remove_tag_from_project/3" do
    test "removes tag from project" do
      project = insert(:project)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})
      assert {:ok, %ProjectTag{}} = Tags.associate_tag_with_project(project, tag)

      assert {:ok, %ProjectTag{}, :removed_from_entity} =
               Tags.remove_tag_from_project(project, tag)
    end

    test "returns error when association doesn't exist" do
      project = insert(:project)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})

      assert {:error, :not_found} = Tags.remove_tag_from_project(project, tag)
    end

    test "with remove_if_unused: true deletes unused tag" do
      project = insert(:project)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})
      assert {:ok, %ProjectTag{}} = Tags.associate_tag_with_project(project, tag)

      assert {:ok, %Tag{}, :completely_removed} =
               Tags.remove_tag_from_project(project, tag, remove_if_unused: true)

      assert Tags.get_tag_by_name("Biology") == nil
    end

    test "with remove_if_unused: true keeps tag when used elsewhere" do
      project1 = insert(:project)
      project2 = insert(:project)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})
      assert {:ok, %ProjectTag{}} = Tags.associate_tag_with_project(project1, tag)
      assert {:ok, %ProjectTag{}} = Tags.associate_tag_with_project(project2, tag)

      assert {:ok, %ProjectTag{}, :removed_from_entity} =
               Tags.remove_tag_from_project(project1, tag, remove_if_unused: true)

      assert Tags.get_tag_by_name("Biology") != nil
    end
  end

  describe "remove_tag_from_section/3" do
    test "removes tag from section" do
      section = insert(:section)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})
      assert {:ok, %SectionTag{}} = Tags.associate_tag_with_section(section, tag)

      assert {:ok, %SectionTag{}, :removed_from_entity} =
               Tags.remove_tag_from_section(section, tag)
    end

    test "removes tag from product" do
      product = insert(:section, %{type: :blueprint})
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})
      assert {:ok, %SectionTag{}} = Tags.associate_tag_with_section(product, tag)

      assert {:ok, %SectionTag{}, :removed_from_entity} =
               Tags.remove_tag_from_section(product, tag)
    end

    test "returns error when association doesn't exist" do
      section = insert(:section)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})

      assert {:error, :not_found} = Tags.remove_tag_from_section(section, tag)
    end

    test "with remove_if_unused: true deletes unused tag" do
      section = insert(:section)
      {:ok, tag} = Tags.create_tag(%{name: "Biology"})
      assert {:ok, %SectionTag{}} = Tags.associate_tag_with_section(section, tag)

      assert {:ok, %Tag{}, :completely_removed} =
               Tags.remove_tag_from_section(section, tag, remove_if_unused: true)

      assert Tags.get_tag_by_name("Biology") == nil
    end
  end

  describe "get_project_tags/1" do
    test "returns all tags associated with a project" do
      project = insert(:project)
      {:ok, tag1} = Tags.create_tag(%{name: "Biology"})
      {:ok, tag2} = Tags.create_tag(%{name: "Chemistry"})
      assert {:ok, _} = Tags.associate_tag_with_project(project, tag1)
      assert {:ok, _} = Tags.associate_tag_with_project(project, tag2)

      tags = Tags.get_project_tags(project)
      assert length(tags) == 2
      tag_names = Enum.map(tags, & &1.name)
      assert "Biology" in tag_names
      assert "Chemistry" in tag_names
    end

    test "returns empty list when project has no tags" do
      project = insert(:project)

      tags = Tags.get_project_tags(project)
      assert tags == []
    end

    test "returns tags in alphabetical order" do
      project = insert(:project)
      {:ok, tag_c} = Tags.create_tag(%{name: "Chemistry"})
      {:ok, tag_a} = Tags.create_tag(%{name: "Biology"})
      assert {:ok, _} = Tags.associate_tag_with_project(project, tag_c)
      assert {:ok, _} = Tags.associate_tag_with_project(project, tag_a)

      tags = Tags.get_project_tags(project)
      assert hd(tags).name == "Biology"
    end
  end

  describe "get_section_tags/1" do
    test "returns all tags associated with a section" do
      section = insert(:section)
      {:ok, tag1} = Tags.create_tag(%{name: "Biology"})
      {:ok, tag2} = Tags.create_tag(%{name: "Chemistry"})
      assert {:ok, _} = Tags.associate_tag_with_section(section, tag1)
      assert {:ok, _} = Tags.associate_tag_with_section(section, tag2)

      tags = Tags.get_section_tags(section)
      assert length(tags) == 2
      tag_names = Enum.map(tags, & &1.name)
      assert "Biology" in tag_names
      assert "Chemistry" in tag_names
    end

    test "returns all tags associated with a product" do
      product = insert(:section, %{type: :blueprint})
      {:ok, tag1} = Tags.create_tag(%{name: "Biology"})
      {:ok, tag2} = Tags.create_tag(%{name: "Chemistry"})
      assert {:ok, _} = Tags.associate_tag_with_section(product, tag1)
      assert {:ok, _} = Tags.associate_tag_with_section(product, tag2)

      tags = Tags.get_section_tags(product)
      assert length(tags) == 2
    end

    test "returns empty list when section has no tags" do
      section = insert(:section)

      tags = Tags.get_section_tags(section)
      assert tags == []
    end

    test "returns tags in alphabetical order" do
      section = insert(:section)
      {:ok, tag_c} = Tags.create_tag(%{name: "Chemistry"})
      {:ok, tag_a} = Tags.create_tag(%{name: "Biology"})
      assert {:ok, _} = Tags.associate_tag_with_section(section, tag_c)
      assert {:ok, _} = Tags.associate_tag_with_section(section, tag_a)

      tags = Tags.get_section_tags(section)
      assert hd(tags).name == "Biology"
    end
  end

  describe "get_or_create_tag/1" do
    test "gets existing tag" do
      {:ok, existing_tag} = Tags.create_tag(%{name: "Biology"})

      assert {:ok, tag} = Tags.get_or_create_tag("Biology")
      assert tag.id == existing_tag.id
    end

    test "creates new tag when it doesn't exist" do
      assert {:ok, %Tag{} = tag} = Tags.get_or_create_tag("New Tag")
      assert tag.name == "New Tag"
    end
  end

  describe "search_tags/2" do
    test "returns tags matching search term" do
      {:ok, _tag1} = Tags.create_tag(%{name: "Biology"})
      {:ok, _tag2} = Tags.create_tag(%{name: "Chemistry"})
      {:ok, _tag3} = Tags.create_tag(%{name: "Biochemistry"})

      tags = Tags.search_tags("bio")
      tag_names = Enum.map(tags, & &1.name)
      assert "Biology" in tag_names
      assert "Biochemistry" in tag_names
      refute "Chemistry" in tag_names
    end

    test "limits search results" do
      {:ok, _tag1} = Tags.create_tag(%{name: "Biology"})
      {:ok, _tag2} = Tags.create_tag(%{name: "Biochemistry"})
      {:ok, _tag3} = Tags.create_tag(%{name: "Biotechnology"})

      tags = Tags.search_tags("bio", 2)
      assert length(tags) == 2
    end

    test "returns empty list when no matches" do
      {:ok, _tag} = Tags.create_tag(%{name: "Chemistry"})

      tags = Tags.search_tags("nonexistent")
      assert tags == []
    end

    test "returns results in alphabetical order" do
      {:ok, _tag1} = Tags.create_tag(%{name: "Biotechnology"})
      {:ok, _tag2} = Tags.create_tag(%{name: "Biology"})

      tags = Tags.search_tags("bio")
      assert hd(tags).name == "Biology"
    end
  end
end
