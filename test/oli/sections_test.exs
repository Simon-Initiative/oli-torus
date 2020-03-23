defmodule Oli.SectionsTest do
  use Oli.DataCase

  alias Oli.Sections

  describe "sections" do
    alias Oli.Sections.Section

    @valid_attrs %{end_date: ~D[2010-04-17], open_and_free: true, registration_open: true, start_date: ~D[2010-04-17], time_zone: "some time_zone", title: "some title"}
    @update_attrs %{end_date: ~D[2011-05-18], open_and_free: false, registration_open: false, start_date: ~D[2011-05-18], time_zone: "some updated time_zone", title: "some updated title"}
    @invalid_attrs %{end_date: nil, open_and_free: nil, registration_open: nil, start_date: nil, time_zone: nil, title: nil}

    def section_fixture(attrs \\ %{}) do
      {:ok, section} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Sections.create_section()

      section
    end

    test "list_sections/0 returns all sections" do
      section = section_fixture()
      assert Sections.list_sections() == [section]
    end

    test "get_section!/1 returns the section with given id" do
      section = section_fixture()
      assert Sections.get_section!(section.id) == section
    end

    test "create_section/1 with valid data creates a section" do
      assert {:ok, %Section{} = section} = Sections.create_section(@valid_attrs)
      assert section.end_date == ~D[2010-04-17]
      assert section.open_and_free == true
      assert section.registration_open == true
      assert section.start_date == ~D[2010-04-17]
      assert section.time_zone == "some time_zone"
      assert section.title == "some title"
    end

    test "create_section/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sections.create_section(@invalid_attrs)
    end

    test "update_section/2 with valid data updates the section" do
      section = section_fixture()
      assert {:ok, %Section{} = section} = Sections.update_section(section, @update_attrs)
      assert section.end_date == ~D[2011-05-18]
      assert section.open_and_free == false
      assert section.registration_open == false
      assert section.start_date == ~D[2011-05-18]
      assert section.time_zone == "some updated time_zone"
      assert section.title == "some updated title"
    end

    test "update_section/2 with invalid data returns error changeset" do
      section = section_fixture()
      assert {:error, %Ecto.Changeset{}} = Sections.update_section(section, @invalid_attrs)
      assert section == Sections.get_section!(section.id)
    end

    test "delete_section/1 deletes the section" do
      section = section_fixture()
      assert {:ok, %Section{}} = Sections.delete_section(section)
      assert_raise Ecto.NoResultsError, fn -> Sections.get_section!(section.id) end
    end

    test "change_section/1 returns a section changeset" do
      section = section_fixture()
      assert %Ecto.Changeset{} = Sections.change_section(section)
    end
  end
end
