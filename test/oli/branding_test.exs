defmodule Oli.BrandingTest do
  use Oli.DataCase

  alias Oli.Branding
  alias Oli.Institutions.Institution

  describe "brands" do
    alias Oli.Branding.Brand

    @valid_attrs %{
      favicons: "some favicons",
      logo: "some logo",
      logo_dark: "some logo_dark",
      name: "some name"
    }
    @update_attrs %{
      favicons: "some updated favicons",
      logo: "some updated logo",
      logo_dark: "some updated logo_dark",
      name: "some updated name"
    }
    @invalid_attrs %{favicons: nil, logo: nil, logo_dark: nil, name: nil}

    def brand_fixture(attrs \\ %{}) do
      {:ok, brand} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Branding.create_brand()

      brand
    end

    test "list_brands/0 returns all brands" do
      brand = brand_fixture()
      assert Branding.list_brands() == [brand]
    end

    test "get_brand!/1 returns the brand with given id" do
      brand = brand_fixture()
      assert Branding.get_brand!(brand.id) == brand
    end

    test "create_brand/1 with valid data creates a brand" do
      assert {:ok, %Brand{} = brand} = Branding.create_brand(@valid_attrs)
      assert brand.favicons == "some favicons"
      assert brand.logo == "some logo"
      assert brand.logo_dark == "some logo_dark"
      assert brand.name == "some name"
    end

    test "create_brand/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Branding.create_brand(@invalid_attrs)
    end

    test "update_brand/2 with valid data updates the brand" do
      brand = brand_fixture()
      assert {:ok, %Brand{} = brand} = Branding.update_brand(brand, @update_attrs)
      assert brand.favicons == "some updated favicons"
      assert brand.logo == "some updated logo"
      assert brand.logo_dark == "some updated logo_dark"
      assert brand.name == "some updated name"
    end

    test "update_brand/2 with invalid data returns error changeset" do
      brand = brand_fixture()
      assert {:error, %Ecto.Changeset{}} = Branding.update_brand(brand, @invalid_attrs)
      assert brand == Branding.get_brand!(brand.id)
    end

    test "delete_brand/1 deletes the brand" do
      brand = brand_fixture()
      assert {:ok, %Brand{}} = Branding.delete_brand(brand)
      assert_raise Ecto.NoResultsError, fn -> Branding.get_brand!(brand.id) end
    end

    test "change_brand/1 returns a brand changeset" do
      brand = brand_fixture()
      assert %Ecto.Changeset{} = Branding.change_brand(brand)
    end
  end

  describe "branding" do
    setup do
      jwk = jwk_fixture()
      author = author_fixture()

      %{project: project, institution: institution} =
        Oli.Seeder.base_project_with_resource(author)

      registration = registration_fixture(%{tool_jwk_id: jwk.id})

      deployment =
        deployment_fixture(%{institution_id: institution.id, registration_id: registration.id})

      {:ok, publication} = Oli.Publishing.publish_project(project, "some changes")

      section =
        section_fixture(%{
          context_id: "some-context-id",
          base_project_id: project.id,
          institution_id: institution.id,
          lti_1p3_deployment_id: deployment.id
        })

      oaf_section =
        section_fixture(%{
          context_id: UUID.uuid4(),
          base_project_id: project.id,
          open_and_free: true,
          registration_open: true
        })

      %{
        section: section,
        oaf_section: oaf_section,
        institution: institution,
        registration: registration,
        publication: publication
      }
    end

    @tag capture_log: true
    test "brand_name returns brand name with correct precedence", %{
      section: section,
      oaf_section: oaf_section,
      institution: institution
    } do
      # section and registration without brand
      assert Branding.brand_name(section) == "OLI Torus Test"

      # create registration brand
      institution_brand = brand_fixture(%{name: "Institution Brand"})

      {:ok, _institution} =
        institution
        |> Institution.changeset(%{default_brand_id: institution_brand.id})
        |> Repo.update()

      assert Branding.brand_name(section) == "Institution Brand"

      # create section brand
      section_brand = brand_fixture(%{name: "Section Brand"})

      {:ok, section} =
        section
        |> Oli.Delivery.Sections.Section.changeset(%{brand_id: section_brand.id})
        |> Repo.update()

      assert Branding.brand_name(section) == "Section Brand"

      # open and free brand
      oaf_brand = brand_fixture(%{name: "Open and Free Brand"})

      {:ok, oaf_section} =
        oaf_section
        |> Oli.Delivery.Sections.Section.changeset(%{brand_id: oaf_brand.id})
        |> Repo.update()

      assert Branding.brand_name(oaf_section) == "Open and Free Brand"
    end

    @tag capture_log: true
    test "brand_logo_url returns brand logo url", %{section: section} do
      section_brand = brand_fixture()

      {:ok, section} =
        Oli.Delivery.Sections.update_section(section, %{brand_id: section_brand.id})

      assert Branding.brand_logo_url(section) == "some logo"
    end

    @tag capture_log: true
    test "brand_logo_url_dark returns dark mode brand logo url", %{section: section} do
      section_brand = brand_fixture()

      {:ok, section} =
        Oli.Delivery.Sections.update_section(section, %{brand_id: section_brand.id})

      assert Branding.brand_logo_url_dark(section) == "some logo_dark"
    end

    @tag capture_log: true
    test "favicons returns favicons", %{section: section} do
      section_brand = brand_fixture()

      {:ok, section} =
        Oli.Delivery.Sections.update_section(section, %{brand_id: section_brand.id})

      assert Branding.favicons("icon.png", section) == "some favicons/icon.png"
    end
  end
end
