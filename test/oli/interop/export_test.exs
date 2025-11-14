defmodule Oli.Interop.ExportTest do
  use OliWeb.ConnCase

  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Certificate
  alias Oli.Interop.Export
  alias Oli.Publishing.AuthoringResolver
  alias Oli.Resources

  import Oli.Factory

  @certificate_params %{
    required_discussion_posts: 11,
    required_class_notes: 12,
    min_percentage_for_completion: 0.9,
    min_percentage_for_distinction: 0.99,
    assessments_apply_to: :all,
    custom_assessments: [],
    requires_instructor_approval: true,
    title: "My Certificate",
    description: "Some certificate description"
  }

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

    test "carry over products and their settings", %{section: section, export: export} do
      product_id = section.id

      {:ok, product_json} = Jason.decode(Map.get(export, ~c"_product-#{product_id}.json"))

      assert product_json["type"] == "Product"
      assert product_json["title"] == section.title
      assert product_json["description"] == section.description

      assert product_json["welcomeTitle"] == %{"test" => "Product welcome title test"}
      assert product_json["encouragingSubtitle"] == "Product encouraging subtitle test"

      assert product_json["gracePeriodDays"] == section.grace_period_days
      assert product_json["payByInstitution"] == section.pay_by_institution
      assert product_json["paymentOptions"] == "#{section.payment_options}"
      assert product_json["amount"]["amount"] == "#{section.amount.amount}"
      assert product_json["amount"]["currency"] == "#{section.amount.currency}"
      assert product_json["amount"]["amount"] == "33.50"
      assert product_json["amount"]["currency"] == "USD"
      assert product_json["requiresPayment"] == section.requires_payment
    end

    test "export and import a project", ctx do
      %{project: project, author: author, section: exported_product} = ctx

      {:ok, %{id: project_id} = _imported_project} =
        project
        |> Export.export()
        |> unzip_to_memory()
        |> Oli.Interop.Ingest.process(author)

      imported_product =
        Sections.get_section_by(base_project_id: project_id) |> Oli.Repo.preload(:certificate)

      assert imported_product.type == exported_product.type
      assert imported_product.title == exported_product.title
      assert imported_product.description == exported_product.description

      assert imported_product.welcome_title == imported_product.welcome_title
      assert imported_product.encouraging_subtitle == imported_product.encouraging_subtitle

      assert imported_product.grace_period_days == exported_product.grace_period_days
      assert imported_product.pay_by_institution == exported_product.pay_by_institution
      assert imported_product.payment_options == exported_product.payment_options
      assert imported_product.amount.amount == exported_product.amount.amount
      assert imported_product.amount.currency == exported_product.amount.currency
      assert Decimal.equal?(imported_product.amount.amount, Decimal.new("33.50"))
      assert imported_product.requires_payment == exported_product.requires_payment

      assert %Certificate{} = imported_product.certificate

      assert @certificate_params = imported_product.certificate
    end
  end

  describe "export handles nil" do
    setup [:setup_project_with_survey]

    test "success: when having nil revisions", %{project: project} do
      author = hd(project.authors)

      root_revision = AuthoringResolver.root_container(project.slug)

      ## Modify the root revision to have a non-revision child resource
      params = %{children: [1000], author_id: author.id}
      Resources.update_revision(root_revision, params)

      {:ok, export: export} = setup_export(%{project: project})

      {:ok, hierarchy_json} = Jason.decode(Map.get(export, ~c"_hierarchy.json"))

      assert hierarchy_json["children"] |> Enum.filter(&(&1 == nil)) |> length() == 1
    end

    test "success: when having nil certificate", ctx do
      %{project: project, author: author, section: section} = ctx

      %{certificate: %Certificate{}} = section = Oli.Repo.preload(section, :certificate)

      section = Sections.update_section!(section, %{certificate: nil})

      refute Oli.Repo.preload(section, :certificate).certificate

      {:ok, %{id: project_id} = _imported_project} =
        project
        |> Export.export()
        |> unzip_to_memory()
        |> Oli.Interop.Ingest.process(author)

      imported_product =
        Sections.get_section_by(base_project_id: project_id) |> Oli.Repo.preload(:certificate)

      refute imported_product.certificate
    end

    test "check default values are applied when product fields are missing during ingestion", %{
      project: project,
      author: author
    } do
      product_json = %{"type" => "Product", "title" => "Minimal Product"}

      # Manually create a digest with this product
      project_json =
        Jason.encode!(%{"title" => project.title, "description" => project.description})

      product_json_str = Jason.encode!(product_json)
      hierarchy_json = Jason.encode!(%{"children" => []})
      media_manifest_json = Jason.encode!(%{"mediaItems" => []})

      digest = %{
        ~c"_project.json" => project_json,
        ~c"_product-test.json" => product_json_str,
        ~c"_hierarchy.json" => hierarchy_json,
        ~c"_media-manifest.json" => media_manifest_json
      }

      {:ok, imported_project} = Oli.Interop.Ingest.process(digest, author)

      imported_product =
        Sections.get_section_by(base_project_id: imported_project.id, type: :blueprint)

      # Verify all defaults were correctly applied
      assert imported_product.title == "Minimal Product"
      assert Decimal.equal?(imported_product.amount.amount, Decimal.new("25"))
      assert imported_product.amount.currency == :USD
      assert imported_product.requires_payment == false
      assert imported_product.payment_options == :direct_and_deferred
      assert imported_product.pay_by_institution == false
      assert imported_product.grace_period_days == 1
      assert imported_product.certificate_enabled == false
      # description, welcome_title, encouraging_subtitle should fallback to project values
      assert imported_product.description == project.description
    end

    test "check invalid amount values fall back to default during ingestion", %{
      project: project,
      author: author
    } do
      # Test with invalid amount and currency values
      test_cases = [
        {%{"amount" => "", "currency" => "USD"}, :USD},
        {%{"amount" => "abc", "currency" => "USD"}, :USD},
        {%{"amount" => nil, "currency" => "EUR"}, :EUR},
        {%{"amount" => "33.50", "currency" => ""}, :USD},
        {%{"amount" => "33.50", "currency" => nil}, :USD}
      ]

      Enum.each(test_cases, fn {amount_data, expected_currency} ->
        product_json = %{
          "type" => "Product",
          "title" => "Product with Invalid Amount",
          "amount" => amount_data
        }

        project_json =
          Jason.encode!(%{"title" => project.title, "description" => project.description})

        product_json_str = Jason.encode!(product_json)
        hierarchy_json = Jason.encode!(%{"children" => []})
        media_manifest_json = Jason.encode!(%{"mediaItems" => []})

        digest = %{
          ~c"_project.json" => project_json,
          ~c"_product-test.json" => product_json_str,
          ~c"_hierarchy.json" => hierarchy_json,
          ~c"_media-manifest.json" => media_manifest_json
        }

        {:ok, imported_project} = Oli.Interop.Ingest.process(digest, author)

        imported_product =
          Sections.get_section_by(base_project_id: imported_project.id, type: :blueprint)

        # For invalid amounts, verify fallback to default $25
        # For valid amounts with invalid currency, verify amount is preserved but currency defaults to USD
        case Decimal.cast(amount_data["amount"]) do
          {:ok, _} ->
            # Valid amount, should be preserved
            assert Decimal.equal?(
                     imported_product.amount.amount,
                     Decimal.new(amount_data["amount"])
                   )

          :error ->
            # Invalid amount, should fall back to $25
            assert Decimal.equal?(imported_product.amount.amount, Decimal.new("25"))
        end

        # Verify currency handling
        assert imported_product.amount.currency == expected_currency
      end)
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
        description: "Test product description",
        amount: Money.new("33.50", "USD"),
        grace_period_days: 12,
        welcome_title: %{test: "Product welcome title test"},
        encouraging_subtitle: "Product encouraging subtitle test",
        pay_by_institution: true
      })

    certificate_params = Map.put(@certificate_params, :section, section)

    certificate = insert(:certificate, certificate_params)

    container_revision =
      insert(:revision, %{resource_type_id: Oli.Resources.ResourceType.id_for_container()})

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

    {:ok, project: project, section: section, author: author, certificate: certificate}
  end
end
