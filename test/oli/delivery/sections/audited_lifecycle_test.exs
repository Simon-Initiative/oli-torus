defmodule Oli.Delivery.Sections.AuditedLifecycleTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Audited
  alias Oli.Delivery.Sections.Section
  alias Oli.Utils.Seeder

  setup do
    author = insert(:author)

    seeds =
      Seeder.Project.create_sample_project(%{}, author,
        project_tag: :project,
        publication_tag: :publication
      )

    Seeder.Project.ensure_published(seeds, seeds.publication)
    publication = Oli.Publishing.get_latest_published_publication_by_slug(seeds.project.slug)

    %{author: author, project: seeds.project, publication: publication}
  end

  describe "sections created outside the course builder" do
    test "from a publication, with the section's identity and scope", %{
      author: author,
      project: project,
      publication: publication
    } do
      instructor = insert(:user)
      context = Oli.Auditing.Context.for_actor(author, source: :api)

      assert {:ok, section} =
               Audited.create_section_from_publication(
                 context,
                 publication,
                 section_attrs(project, "From Publication"),
                 rebuild: true,
                 enroll: instructor
               )

      event = assert_audited(:section_created, section_id: section.id, actor: author)

      assert {event.entity_type, event.entity_id, event.project_id} ==
               {:section, to_string(section.id), project.id}

      assert event.entity_snapshot["title"] == "From Publication"
      assert event.details["section_title"] == "From Publication"
      assert event.event_key == "section:#{section.id}:created"
      assert Sections.is_instructor?(instructor, section.slug)
    end

    test "from a product, naming the product", %{author: author, project: project} do
      {:ok, product} = Audited.create_product(audit_context(), project.slug, "Template", nil)

      assert {:ok, section} =
               Audited.create_section_from_product(
                 Oli.Auditing.Context.for_actor(author, source: :api),
                 product,
                 section_attrs(project, "From Product") |> Map.put(:blueprint_id, product.id)
               )

      event = assert_audited(:section_created, section_id: section.id, actor: author)
      assert event.details["blueprint_id"] == product.id
    end

    test "nothing is created when the event cannot be recorded", %{
      project: project,
      publication: publication
    } do
      reject_audit_inserts()

      assert {:error, _} =
               capture_log_result(fn ->
                 Audited.create_section_from_publication(
                   audit_context(),
                   publication,
                   section_attrs(project, "Unrecorded")
                 )
               end)

      refute Repo.get_by(Section, title: "Unrecorded")
    end
  end

  describe "products" do
    test "creation records a template event", %{project: project} do
      assert {:ok, product} =
               Audited.create_product(audit_context(), project.slug, "Template", nil)

      event = assert_audited(:product_created, section_id: product.id, project_id: project.id)
      assert {event.entity_type, event.event_key} == {:product, "product:#{product.id}:created"}
      assert event.details["type"] == "blueprint"
    end

    test "creation rolls back when the event cannot be recorded", %{project: project} do
      reject_audit_inserts()

      assert {:error, _} =
               capture_log_result(fn ->
                 Audited.create_product(audit_context(), project.slug, "Unrecorded", nil)
               end)

      refute Repo.get_by(Section, title: "Unrecorded")
    end

    test "only products can be duplicated", %{project: project} do
      section = insert(:section, base_project: project, type: :enrollable)

      assert {:error, :invalid_request} = Audited.duplicate_product(audit_context(), section)
    end
  end

  describe "archival and deletion" do
    test "archiving a product records a template event with the status change", %{
      project: project
    } do
      {:ok, product} = Audited.create_product(audit_context(), project.slug, "Template", nil)

      assert {:ok, %Section{status: :archived}} =
               Audited.archive_section(audit_context(), product)

      event = assert_audited(:product_archived, section_id: product.id)

      assert event.changes["status"] == %{
               "operation" => "set",
               "before" => "active",
               "after" => "archived"
             }
    end

    test "a section already in the target status records nothing" do
      archived = insert(:section, status: :archived)
      deleted = insert(:section, status: :deleted)

      assert {:ok, _} = Audited.archive_section(audit_context(), archived)
      assert {:ok, _} = Audited.delete_section(audit_context(), deleted)

      assert audit_events(:section_archived, section_id: archived.id) == []
      assert audit_events(:section_deleted, section_id: deleted.id) == []
    end

    test "deletion rolls back when the event cannot be recorded" do
      section = insert(:section, status: :active)
      reject_audit_inserts()

      assert {:error, _} =
               capture_log_result(fn -> Audited.delete_section(audit_context(), section) end)

      assert Repo.get!(Section, section.id).status == :active
    end
  end

  defp section_attrs(project, title) do
    %{
      title: title,
      type: :enrollable,
      base_project_id: project.id,
      context_id: UUID.uuid4(),
      open_and_free: true
    }
  end

  defp capture_log_result(fun) do
    {result, _log} = ExUnit.CaptureLog.with_log(fun)
    result
  end
end
