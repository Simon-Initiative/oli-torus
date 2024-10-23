defmodule Oli.Interop.ExportTest do
  use OliWeb.ConnCase

  alias Oli.Delivery.Sections.Section
  alias Oli.Interop.Export
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources
  import Oli.Factory

  describe "export" do
    setup [:setup_project_with_survey, :setup_export]

    test "project export preserves student surveys", %{project: project, export: export} do
      {:ok, project_json} = Jason.decode(Map.get(export, ~c"_project.json"))

      assert project_json["required_student_survey"] ==
               Integer.to_string(project.required_survey_resource_id)
    end

    test "project export preserves attributes", %{project: project, export: export} do
      {:ok, project_json} = Jason.decode(Map.get(export, ~c"_project.json"))

      # Check that learning language in the project attributes is preserved
      assert project_json["attributes"]["learning_language"] ==
               project.attributes.learning_language
    end

    test "project export preserves customizations", %{project: project, export: export} do
      {:ok, hierarchy_json} = Jason.decode(Map.get(export, ~c"_hierarchy.json"))

      [type_labels] = hierarchy_json["children"] |> Enum.filter(&(&1["type"] == "labels"))

      # Check that customizations in the project are preserved
      assert type_labels["unit"] == project.customizations.unit
      assert type_labels["module"] == project.customizations.module
      assert type_labels["section"] == project.customizations.section
    end

    test "project export preserves welcome title and encouraging subtitle", %{export: export} do
      {:ok, project_json} = Jason.decode(Map.get(export, ~c"_project.json"))

      assert project_json["welcomeTitle"] == %{"test" => "test"}
      assert project_json["encouragingSubtitle"] == "Subtitle test"
    end

    test "export a project with nil revisions does not fail", %{project: project} do
      author = hd(project.authors)

      root_revision = AuthoringResolver.root_container(project.slug)

      ## Modify the root revision to have a non-revision child resource
      params = %{children: [1000], author_id: author.id}
      Resources.update_revision(root_revision, params)

      export =
        Export.export(project)
        |> unzip_to_memory()
        |> Enum.reduce(%{}, fn {f, c}, m -> Map.put(m, f, c) end)

      {:ok, hierarchy_json} = Jason.decode(Map.get(export, ~c"_hierarchy.json"))

      assert hierarchy_json["children"] |> Enum.filter(&(&1 == nil)) |> length() == 1
    end

    test "carry over products and their settings", %{section: section, export: export} do
      product_id = section.id

      {:ok, product_json} = Jason.decode(Map.get(export, ~c"#{product_id}.json"))

      assert product_json["type"] == "Product"
      assert product_json["title"] == section.title

      assert product_json["welcomeTitle"] == %{"test" => "Product welcome title test"}
      assert product_json["encouragingSubtitle"] == "Product encouraging subtitle test"

      assert product_json["gracePeriodDays"] == section.grace_period_days
      assert product_json["payByInstitution"] == section.pay_by_institution
      assert product_json["paymentOptions"] == "#{section.payment_options}"
      assert product_json["amount"]["amount"] == "#{section.amount.amount}"
      assert product_json["amount"]["currency"] == "#{section.amount.currency}"
      assert product_json["requiresPayment"] == section.requires_payment
    end

    test "export and import a project", %{
      project: project,
      author: author,
      section: exported_product
    } do
      {:ok, imported_project} =
        project
        |> Export.export()
        |> unzip_to_memory()
        |> Oli.Interop.Ingest.process(author)

      imported_product = Oli.Repo.get_by!(Section, %{base_project_id: imported_project.id})

      assert imported_product.type == exported_product.type
      assert imported_product.title == exported_product.title

      assert imported_product.welcome_title == imported_product.welcome_title
      assert imported_product.encouraging_subtitle == imported_product.encouraging_subtitle

      assert imported_product.grace_period_days == exported_product.grace_period_days
      assert imported_product.pay_by_institution == exported_product.pay_by_institution
      assert imported_product.payment_options == exported_product.payment_options
      assert imported_product.amount.amount == exported_product.amount.amount
      assert imported_product.amount.currency == exported_product.amount.currency
      assert imported_product.requires_payment == exported_product.requires_payment
    end
  end

  defp setup_export(ctx) do
    export =
      Export.export(ctx.project)
      |> unzip_to_memory()
      |> Enum.reduce(%{}, fn {f, c}, m -> Map.put(m, f, c) end)

    {:ok, export: export}
  end

  defp setup_project_with_survey(_) do
    author = insert(:author)

    survey_revision =
      insert(:revision, resource_type_id: Oli.Resources.ResourceType.id_for_page())

    project =
      insert(:project,
        slug: "project_with_survey",
        required_survey_resource_id: survey_revision.resource.id,
        authors: [author],
        attributes: %{learning_language: "es"},
        customizations: %{
          unit: "Unit_Example",
          module: "Module_Example",
          section: "Section_Example"
        },
        welcome_title: %{test: "test"},
        encouraging_subtitle: "Subtitle test"
      )

    section =
      insert(:section, %{
        base_project: project,
        status: :active,
        type: :blueprint,
        amount: Money.new(:USD, "88.00"),
        grace_period_days: 12,
        welcome_title: %{test: "Product welcome title test"},
        encouraging_subtitle: "Product encouraging subtitle test",
        pay_by_institution: true
      })

    container_revision =
      insert(:revision, %{
        resource_type_id: Oli.Resources.ResourceType.id_for_container()
      })

    publication =
      insert(:publication, %{
        project: project,
        root_resource_id: container_revision.resource.id,
        published: nil
      })

    insert(:section_project_publication, %{
      project: project,
      section: section,
      publication: publication
    })

    insert(:section_resource, %{
      project: project,
      section: section,
      resource_id: container_revision.resource.id
    })

    insert(:published_resource, %{
      publication: publication,
      resource: survey_revision.resource,
      revision: survey_revision,
      author: author
    })

    insert(:published_resource, %{
      publication: publication,
      resource: container_revision.resource,
      revision: container_revision,
      author: author
    })

    insert(:project_resource, %{project_id: project.id, resource_id: survey_revision.resource.id})

    insert(:project_resource, %{
      project_id: project.id,
      resource_id: container_revision.resource.id
    })

    {:ok, project: project, section: section, author: author}
  end
end
