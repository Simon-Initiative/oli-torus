defmodule Oli.Delivery.Sections.BlueprintTest do
  use Oli.DataCase

  import Oli.Factory
  import Ecto.Query, warn: false

  alias Oli.Authoring.Course
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Blueprint
  alias Oli.Publishing
  alias Oli.Repo.{Paging, Sorting}
  alias Oli.Publishing.DeliveryResolver

  alias Oli.Resources.ResourceType

  describe "duplicate/2" do
    @page_type_id ResourceType.get_id_by_type("page")
    @container_type_id ResourceType.get_id_by_type("container")
    @keys_to_take [:title, :blueprint_id, :required_survey_resource_id, :has_experiments]
    @one_week_ago DateTime.utc_now() |> DateTime.add(-7, :day) |> DateTime.truncate(:second)
    @a_day_later DateTime.utc_now() |> DateTime.add(-6, :day) |> DateTime.truncate(:second)

    @updates %{
      start_date: @one_week_ago,
      end_date: @a_day_later,
      max_attempts: 200,
      retake_mode: :targeted,
      assessment_mode: :traditional,
      late_submit: :disallow,
      late_start: :disallow,
      time_limit: 90,
      grace_period: 100,
      password: "12345",
      scoring_strategy_id: 2,
      review_submission: :disallow,
      feedback_mode: :scheduled,
      feedback_scheduled_date: @a_day_later
    }

    test "section's setting is inherited from a project" do
      # Project and Author
      %{authors: [author]} = project = create_project_with_assocs()

      # Root container
      %{resource: container_resource, revision: container_revision, publication: publication} =
        create_bundle_for(@container_type_id, project, author, nil, nil, title: "Root container")

      # Page resource
      %{resource: page_resource} =
        create_bundle_for(@page_type_id, project, author, publication, nil, graded: true)

      # Link container - page
      assoc_resources([page_resource], container_revision, container_resource, publication)

      # Section and its section_resources
      {:ok, blueprint} =
        insert(:section, base_project: project, open_and_free: true, type: :blueprint)
        |> Sections.create_section_resources(publication)

      # Update page's section_resource
      {:ok, sr_page_blueprint} =
        get_section_resource_by_resource(page_resource)
        |> Oli.Delivery.Sections.update_section_resource(@updates)

      section_params =
        Map.merge(Map.take(blueprint, @keys_to_take), %{type: :enrollable, open_and_free: true})

      # Section from product action
      {:ok, duplicate} = Blueprint.duplicate(blueprint, section_params)

      # Grab graded pages and its section_resources (only 1 at this moment)
      [{page_revision_duplicate, sr_page_duplicate}] =
        DeliveryResolver.graded_pages_revisions_and_section_resources(duplicate.slug)

      # Assert duplicate page is also graded
      assert page_revision_duplicate.graded

      # Assert duplicate data is inherited
      assert sr_page_blueprint.end_date == sr_page_duplicate.end_date
      assert sr_page_blueprint.max_attempts == sr_page_duplicate.max_attempts
      assert sr_page_blueprint.retake_mode == sr_page_duplicate.retake_mode
      assert sr_page_blueprint.assessment_mode == sr_page_duplicate.assessment_mode
      assert sr_page_blueprint.late_submit == sr_page_duplicate.late_submit
      assert sr_page_blueprint.late_start == sr_page_duplicate.late_start
      assert sr_page_blueprint.time_limit == sr_page_duplicate.time_limit
      assert sr_page_blueprint.grace_period == sr_page_duplicate.grace_period
      assert sr_page_blueprint.password == sr_page_duplicate.password
      assert sr_page_blueprint.scoring_strategy_id == sr_page_duplicate.scoring_strategy_id
      assert sr_page_blueprint.review_submission == sr_page_duplicate.review_submission
      assert sr_page_blueprint.feedback_mode == sr_page_duplicate.feedback_mode

      assert sr_page_blueprint.feedback_scheduled_date ==
               sr_page_duplicate.feedback_scheduled_date
    end
  end

  describe "basic blueprint operations" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "is_author_of_blueprint?/2 correctly identifies authors", %{
      project: project,
      institution: institution,
      author: author
    } do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes", author.id)

      # Create a course section using the initial publication
      {:ok, section} =
        Sections.create_section(%{
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id,
          publisher_id: project.publisher_id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      {:ok, duplicate} = Blueprint.duplicate(section)

      assert duplicate.type == :blueprint
      refute duplicate.id == section.id
      refute duplicate.slug == section.slug

      assert Blueprint.is_author_of_blueprint?(duplicate.slug, author.id)
      refute Blueprint.is_author_of_blueprint?(section.slug, author.id)
    end

    test "duplicate/1 deep copies a course section, turning it into a blueprint", %{
      project: project,
      institution: institution,
      author: author
    } do
      {:ok, initial_pub} = Publishing.publish_project(project, "some changes", author.id)

      # Create a course section using the initial publication
      {:ok, section} =
        Sections.create_section(%{
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id,
          publisher_id: project.publisher_id,
          skip_email_verification: true,
          requires_enrollment: true
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      {:ok, %{id: id} = duplicate} = Blueprint.duplicate(section)

      assert duplicate.type == :blueprint
      assert duplicate.skip_email_verification == true
      assert duplicate.registration_open == true
      assert duplicate.requires_enrollment == true
      refute duplicate.id == section.id
      refute duplicate.slug == section.slug
      refute duplicate.root_section_resource_id == section.root_section_resource_id

      # Verify section resources were created and migrated
      section_resources = Sections.get_section_resources(duplicate.id)
      assert length(section_resources) > 0

      section_resources
      |> Enum.each(fn sr ->
        assert sr.section_id == duplicate.id
        # revision_id is a field that is populated by the migration
        assert sr.revision_id != nil
      end)

      duped =
        get_resources(id)
        |> Enum.map(fn s -> s.id end)
        |> MapSet.new()

      original =
        get_resources(section.id)
        |> Enum.map(fn s -> s.id end)
        |> MapSet.new()

      assert MapSet.size(duped) == MapSet.size(original)
      assert MapSet.disjoint?(duped, original)

      duped =
        get_pub_mappings(id)
        |> MapSet.new()

      original =
        get_pub_mappings(section.id)
        |> MapSet.new()

      assert MapSet.size(duped) == MapSet.size(original)
    end

    test "list/0 lists all the active products" do
      active_product_id = insert(:section).id
      insert(:section, status: :deleted)

      assert [%Sections.Section{id: ^active_product_id}] = Blueprint.list()
    end

    test "browse/3 lists products and applies paging" do
      product_id = insert(:section).id
      _product_id_2 = insert(:section).id

      assert [%Sections.Section{id: ^product_id}] =
               Blueprint.browse(%Paging{offset: 0, limit: 1}, %Sorting{
                 direction: :asc,
                 field: :title
               })
    end

    test "browse/3 lists products and applies sorting by base project title" do
      project_1 = insert(:project, title: "A")
      project_2 = insert(:project, title: "B")
      product_id_1 = insert(:section, base_project: project_1).id
      product_id_2 = insert(:section, base_project: project_2).id

      assert [%Sections.Section{id: ^product_id_1}, %Sections.Section{id: ^product_id_2}] =
               Blueprint.browse(%Paging{offset: 0, limit: 2}, %Sorting{
                 direction: :asc,
                 field: :base_project_id
               })
    end

    test "browse/3 lists products and applies sorting by amount" do
      product_id_1 = insert(:section, requires_payment: true, amount: Money.new(:USD, 10)).id
      product_id_2 = insert(:section, requires_payment: true, amount: Money.new(:USD, 20)).id

      assert [%Sections.Section{id: ^product_id_1}, %Sections.Section{id: ^product_id_2}] =
               Blueprint.browse(%Paging{offset: 0, limit: 2}, %Sorting{
                 direction: :asc,
                 field: :requires_payment
               })
    end

    test "browse/3 lists products and applies searching by product title" do
      product_id_1 = insert(:section, title: "A1").id
      _product_id_2 = insert(:section, title: "B1").id

      assert [%Sections.Section{id: ^product_id_1}] =
               Blueprint.browse(
                 %Paging{offset: 0, limit: 2},
                 %Sorting{direction: :asc, field: :title},
                 text_search: "A1"
               )
    end

    test "browse/3 lists products and applies searching by base project title" do
      project_1 = insert(:project, title: "A1")
      project_2 = insert(:project, title: "B1")
      product_id_1 = insert(:section, base_project: project_1).id
      _product_id_2 = insert(:section, base_project: project_2).id

      assert [%Sections.Section{id: ^product_id_1}] =
               Blueprint.browse(
                 %Paging{offset: 0, limit: 2},
                 %Sorting{direction: :asc, field: :title},
                 text_search: "A1"
               )
    end

    @tag :flaky
    test "browse/3 lists products and applies searching by amount" do
      product_id_1 = insert(:section, requires_payment: true, amount: Money.new(:USD, 500)).id
      _product_id_2 = insert(:section, requires_payment: true, amount: Money.new(:USD, 100)).id

      assert [%Sections.Section{id: ^product_id_1}] =
               Blueprint.browse(
                 %Paging{offset: 0, limit: 2},
                 %Sorting{direction: :asc, field: :title},
                 text_search: "500"
               )
    end

    test "browse/3 lists products and applies filtering by base project" do
      project_1 = insert(:project)
      project_2 = insert(:project)
      product_id_1 = insert(:section, base_project: project_1).id
      _product_id_2 = insert(:section, base_project: project_2).id

      assert [%Sections.Section{id: ^product_id_1}] =
               Blueprint.browse(
                 %Paging{offset: 0, limit: 2},
                 %Sorting{direction: :asc, field: :title},
                 project_id: project_1.id
               )
    end

    test "browse/3 lists products and applies filtering by status" do
      archived_product_id = insert(:section, title: "B", status: :archived).id
      product_id = insert(:section, title: "A").id

      assert [%Sections.Section{id: ^product_id}, %Sections.Section{id: ^archived_product_id}] =
               Blueprint.browse(
                 %Paging{offset: 0, limit: 2},
                 %Sorting{direction: :asc, field: :title},
                 include_archived: true
               )
    end

    def get_resources(id) do
      query =
        from(
          s in Oli.Delivery.Sections.SectionResource,
          where: s.section_id == ^id,
          select: s
        )

      Repo.all(query)
    end

    def get_pub_mappings(id) do
      query =
        from(
          s in Oli.Delivery.Sections.SectionsProjectsPublications,
          where: s.section_id == ^id,
          select: s
        )

      Repo.all(query)
    end
  end

  describe "create_blueprint/5" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "successfully creates a blueprint from a valid project", %{
      project: project,
      author: author
    } do
      {:ok, _publication} = Publishing.publish_project(project, "initial publication", author.id)

      custom_labels = %{"unit" => "Module", "lesson" => "Section"}

      attrs = %{
        "requires_payment" => true,
        "payment_options" => "direct",
        "amount" => %{"currency" => "USD", "amount" => "50.00"}
      }

      {:ok, blueprint} =
        Blueprint.create_blueprint(
          project.slug,
          "Test Blueprint",
          custom_labels,
          nil,
          attrs
        )

      # Verify blueprint basic properties
      assert blueprint.type == :blueprint
      assert blueprint.status == :active
      assert blueprint.title == "Test Blueprint"
      assert blueprint.base_project_id == project.id
      assert blueprint.requires_payment == true
      assert blueprint.payment_options == :direct
      assert blueprint.amount == Money.new(:USD, "50.00")
      assert blueprint.customizations.unit == "Module"
      refute blueprint.open_and_free

      # Verify section resources were created and migrated
      section_resources = Sections.get_section_resources(blueprint.id)
      assert length(section_resources) > 0

      section_resources
      |> Enum.each(fn sr ->
        assert sr.section_id == blueprint.id
        # revision_id is a field that is populated by the migration
        assert sr.revision_id != nil
      end)

      # Verify root section resource is set
      assert blueprint.root_section_resource_id != nil

      # Verify section project publication was created
      section_project_publications =
        from(spp in Oli.Delivery.Sections.SectionsProjectsPublications,
          where: spp.section_id == ^blueprint.id,
          select: spp
        )
        |> Repo.all()

      assert length(section_project_publications) == 1
      assert Enum.at(section_project_publications, 0).project_id == project.id
    end

    test "creates blueprint with default values when attrs not provided", %{
      project: project,
      author: author
    } do
      {:ok, _publication} = Publishing.publish_project(project, "initial publication", author.id)

      {:ok, blueprint} =
        Blueprint.create_blueprint(
          project.slug,
          "Default Blueprint",
          %{}
        )

      # Verify default values
      assert blueprint.requires_payment == false
      assert blueprint.payment_options == :direct_and_deferred
      assert blueprint.pay_by_institution == false
      assert blueprint.registration_open == false
      assert blueprint.grace_period_days == 1
      assert blueprint.amount == Money.new(:USD, "25.00")
      assert blueprint.certificate_enabled == false
    end

    test "returns error when project does not exist" do
      assert {:error, {:invalid_project}} =
               Blueprint.create_blueprint(
                 "non-existent-project",
                 "Test Blueprint",
                 %{}
               )
    end
  end

  describe "blueprint availability based on visibility" do
    setup do
      Seeder.base_project_with_resource2()
    end

    test "is_author_of_blueprint?/2 correctly identifies authors", %{
      project: project,
      institution: institution,
      author: author,
      author2: author2
    } do
      another = Seeder.another_project(author2, institution, "second one")

      {:ok, _} =
        Sections.create_section(%{
          type: :blueprint,
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: another.project.id,
          publisher_id: project.publisher_id
        })

      {:ok, initial_pub} = Publishing.publish_project(project, "some changes", author.id)

      # Create a blueprint using the initial publication
      {:ok, section} =
        Sections.create_section(%{
          type: :blueprint,
          title: "1",
          registration_open: true,
          context_id: UUID.uuid4(),
          institution_id: institution.id,
          base_project_id: project.id,
          publisher_id: project.publisher_id
        })
        |> then(fn {:ok, section} -> section end)
        |> Sections.create_section_resources(initial_pub)

      {:ok, _} = Blueprint.duplicate(section)

      # At this point, the author should only have access to two products (the
      # ones build from the project this author created)
      available = Blueprint.available_products(author, institution)
      assert length(available) == 2

      # We then change the other project to be global visibility, but project
      # does not yet have a publication, so the product created from it is not
      # visible.
      Course.update_project(another.project, %{visibility: :global})
      available = Blueprint.available_products(author, institution)
      assert length(available) == 2

      # After publishing the project, the product is now visible
      {:ok, _} = Publishing.publish_project(another.project, "some changes", author.id)
      available = Blueprint.available_products(author, institution)
      assert length(available) == 3
    end

    test "list_products_not_in_community/1 returns the products that are not associated to the community" do
      [first_section | _tail] = insert_list(2, :section)
      community_visibility = insert(:community_visibility, %{section: first_section})

      assert 2 = length(Blueprint.list())

      assert 1 =
               length(Blueprint.list_products_not_in_community(community_visibility.community_id))
    end
  end
end
