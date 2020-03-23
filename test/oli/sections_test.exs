defmodule Oli.SectionsTest do
  use Oli.DataCase

  alias Oli.Sections

  describe "sections" do
    alias Oli.Sections.Section

    alias Oli.Accounts.SystemRole
    alias Oli.Accounts.Institution
    alias Oli.Accounts.Author
    alias Oli.Course.Project
    alias Oli.Course.Family
    alias Oli.Publishing.Publication

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

    setup do

      {:ok, family} = Family.changeset(%Family{}, %{description: "description", slug: "slug", title: "title"}) |> Repo.insert
      {:ok, project} = Project.changeset(%Project{}, %{description: "description", slug: "slug", title: "title", version: "1", family_id: family.id}) |> Repo.insert
      {:ok, publication} = Publication.changeset(%Publication{}, %{description: "description", published: False, root_resources: [], project_id: project.id}) |> Repo.insert
      {:ok, author} = Author.changeset(%Author{}, %{email: "test@test.com", first_name: "First", last_name: "Last", provider: "foo", system_role_id: SystemRole.role_id.author}) |> Repo.insert
      {:ok, institution} = Institution.changeset(%Institution{}, %{name: "CMU", country_code: "some country_code", institution_email: "some institution_email", institution_url: "some institution_url", timezone: "some timezone", consumer_key: "some key", shared_secret: "some secret", author_id: author.id}) |> Repo.insert

      valid_attrs = Map.put(@valid_attrs, :institution_id, institution.id)
        |> Map.put(:project_id, project.id)
        |> Map.put(:publication_id, publication.id)

      {:ok, section} = valid_attrs |> Sections.create_section()

      {:ok, %{section: section, author: author, valid_attrs: valid_attrs}}
    end


    test "create_section/1 with valid data creates a section", %{valid_attrs: valid_attrs} do
      assert {:ok, %Section{} = section} = Sections.create_section(valid_attrs)
      assert section.end_date == ~D[2010-04-17]
      assert section.open_and_free == true
      assert section.registration_open == true
      assert section.start_date == ~D[2010-04-17]
      assert section.time_zone == "some time_zone"
      assert section.title == "some title"
    end

    test "list_sections/0 returns all sections", %{section: section} do
      assert Sections.list_sections() == [section]
    end

    test "get_section!/1 returns the section with given id", %{section: section} do
      assert Sections.get_section!(section.id) == section
    end


    test "create_section/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Sections.create_section(@invalid_attrs)
    end

    test "update_section/2 with valid data updates the section", %{section: section}  do

      assert {:ok, %Section{} = section} = Sections.update_section(section, @update_attrs)
      assert section.end_date == ~D[2011-05-18]
      assert section.open_and_free == false
      assert section.registration_open == false
      assert section.start_date == ~D[2011-05-18]
      assert section.time_zone == "some updated time_zone"
      assert section.title == "some updated title"
    end

    test "update_section/2 with invalid data returns error changeset", %{section: section} do
      assert {:error, %Ecto.Changeset{}} = Sections.update_section(section, @invalid_attrs)
      assert section == Sections.get_section!(section.id)
    end

    test "delete_section/1 deletes the section", %{section: section} do
      assert {:ok, %Section{}} = Sections.delete_section(section)
      assert_raise Ecto.NoResultsError, fn -> Sections.get_section!(section.id) end
    end

    test "change_section/1 returns a section changeset", %{section: section} do
      assert %Ecto.Changeset{} = Sections.change_section(section)
    end
  end
end
