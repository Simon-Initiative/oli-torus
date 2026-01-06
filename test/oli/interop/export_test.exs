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

    test "project export and import preserves bank selection with objective criteria", %{
      project: project,
      author: author
    } do
      # Create objectives
      objective1 =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_objective(),
          title: "Objective 1",
          objectives: %{}
        })

      objective2 =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_objective(),
          title: "Objective 2",
          objectives: %{}
        })

      # Create a tag
      tag =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_tag(),
          title: "Test Tag",
          tags: []
        })

      # Create a page with bank selection containing objective and tag criteria
      page_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Test Page with Bank Selection",
          content: %{
            "model" => [
              %{
                "type" => "selection",
                "id" => "test-selection-1",
                "count" => 2,
                "logic" => %{
                  "conditions" => %{
                    "operator" => "all",
                    "children" => [
                      %{
                        "fact" => "objectives",
                        "operator" => "contains",
                        "value" => [objective1.resource_id, objective2.resource_id]
                      },
                      %{
                        "fact" => "tags",
                        "operator" => "contains",
                        "value" => [tag.resource_id]
                      }
                    ]
                  }
                }
              }
            ]
          }
        })

      # Add resources to project and publication
      publication = Oli.Publishing.project_working_publication(project.slug)

      insert(:project_resource, %{
        project_id: project.id,
        resource_id: objective1.resource.id
      })

      insert(:project_resource, %{
        project_id: project.id,
        resource_id: objective2.resource.id
      })

      insert(:project_resource, %{
        project_id: project.id,
        resource_id: tag.resource.id
      })

      insert(:project_resource, %{
        project_id: project.id,
        resource_id: page_revision.resource.id
      })

      insert(:published_resource, %{
        publication: publication,
        resource: objective1.resource,
        revision: objective1,
        author: hd(project.authors)
      })

      insert(:published_resource, %{
        publication: publication,
        resource: objective2.resource,
        revision: objective2,
        author: hd(project.authors)
      })

      insert(:published_resource, %{
        publication: publication,
        resource: tag.resource,
        revision: tag,
        author: hd(project.authors)
      })

      insert(:published_resource, %{
        publication: publication,
        resource: page_revision.resource,
        revision: page_revision,
        author: hd(project.authors)
      })

      # Store original IDs for verification
      original_objective1_id = objective1.resource_id
      original_objective2_id = objective2.resource_id
      original_tag_id = tag.resource_id

      # Export the project
      export =
        Export.export(project)
        |> unzip_to_memory()
        |> Enum.reduce(%{}, fn {f, c}, m -> Map.put(m, f, c) end)

      # Verify export has IDs
      page_file = "#{page_revision.resource_id}.json"
      {:ok, page_json} = Jason.decode(Map.get(export, String.to_charlist(page_file)))

      [exported_selection] =
        page_json["content"]["model"]
        |> Enum.filter(&(&1["type"] == "selection"))

      exported_logic = exported_selection["logic"]

      [exported_objective_condition, exported_tag_condition] =
        exported_logic["conditions"]["children"]

      assert exported_objective_condition["value"] == [
               original_objective1_id,
               original_objective2_id
             ]

      assert exported_tag_condition["value"] == [original_tag_id]

      # Import the project back
      {:ok, imported_project} = Oli.Interop.Ingest.process(export, author)

      # Find the imported page by title
      imported_page =
        AuthoringResolver.from_title(imported_project.slug, "Test Page with Bank Selection")

      assert length(imported_page) == 1
      imported_page_revision = hd(imported_page)

      # Verify the bank selection is preserved in the imported project
      content = imported_page_revision.content

      [imported_selection] =
        content["model"]
        |> Enum.filter(&(&1["type"] == "selection"))

      assert imported_selection["id"] == "test-selection-1"
      assert imported_selection["count"] == 2

      # Verify logic conditions are preserved
      imported_logic = imported_selection["logic"]
      assert imported_logic["conditions"]["operator"] == "all"
      assert length(imported_logic["conditions"]["children"]) == 2

      [imported_objective_condition, imported_tag_condition] =
        imported_logic["conditions"]["children"]

      # Verify objective condition is preserved
      assert imported_objective_condition["fact"] == "objectives"
      assert imported_objective_condition["operator"] == "contains"
      assert is_list(imported_objective_condition["value"])
      assert length(imported_objective_condition["value"]) == 2

      # Verify the objective IDs are correctly mapped to new resource IDs (integers)
      imported_objective_ids = imported_objective_condition["value"]
      assert Enum.all?(imported_objective_ids, &is_integer/1)

      # Find the imported objectives to verify IDs are correct
      imported_objectives =
        Oli.Publishing.get_unpublished_revisions_by_type(imported_project.slug, "objective")
        |> Enum.filter(fn obj -> obj.title in ["Objective 1", "Objective 2"] end)

      assert length(imported_objectives) == 2
      imported_objective_resource_ids = Enum.map(imported_objectives, & &1.resource_id)

      # Verify the objective IDs in the selection match the imported objectives
      assert Enum.all?(imported_objective_ids, fn id -> id in imported_objective_resource_ids end)

      # Verify tag condition is preserved
      assert imported_tag_condition["fact"] == "tags"
      assert imported_tag_condition["operator"] == "contains"
      assert is_list(imported_tag_condition["value"])
      assert length(imported_tag_condition["value"]) == 1

      # Verify the tag ID is correctly mapped to new resource ID (integer)
      [imported_tag_id] = imported_tag_condition["value"]
      assert is_integer(imported_tag_id)

      # Find the imported tag to verify ID is correct
      imported_tags =
        Oli.Publishing.get_unpublished_revisions_by_type(imported_project.slug, "tag")
        |> Enum.filter(fn t -> t.title == "Test Tag" end)

      assert length(imported_tags) == 1
      [imported_tag] = imported_tags
      assert imported_tag_id == imported_tag.resource_id
    end

    test "project export preserves bank selection with null conditions", %{project: project} do
      # Create a page with bank selection containing null conditions
      page_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Test Page with Null Selection",
          content: %{
            "model" => [
              %{
                "type" => "selection",
                "id" => "test-selection-null",
                "count" => 1,
                "logic" => %{
                  "conditions" => nil
                }
              }
            ]
          }
        })

      # Add page to project and publication
      publication = Oli.Publishing.project_working_publication(project.slug)

      insert(:project_resource, %{
        project_id: project.id,
        resource_id: page_revision.resource.id
      })

      insert(:published_resource, %{
        publication: publication,
        resource: page_revision.resource,
        revision: page_revision,
        author: hd(project.authors)
      })

      # Export the project
      export =
        Export.export(project)
        |> unzip_to_memory()
        |> Enum.reduce(%{}, fn {f, c}, m -> Map.put(m, f, c) end)

      # Find the page in the export
      page_file = "#{page_revision.resource_id}.json"
      {:ok, page_json} = Jason.decode(Map.get(export, String.to_charlist(page_file)))

      # Verify the bank selection with null conditions is preserved
      [selection] =
        page_json["content"]["model"]
        |> Enum.filter(&(&1["type"] == "selection"))

      assert selection["id"] == "test-selection-null"
      assert selection["count"] == 1
      assert selection["logic"]["conditions"] == nil
    end

    test "project export and import preserves bank selection with nested clauses", %{
      project: project,
      author: author
    } do
      # Create objectives
      objective1 =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_objective(),
          title: "Objective 1",
          objectives: %{}
        })

      objective2 =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_objective(),
          title: "Objective 2",
          objectives: %{}
        })

      # Create a page with bank selection containing nested clauses
      page_revision =
        insert(:revision, %{
          resource_type_id: Oli.Resources.ResourceType.id_for_page(),
          title: "Test Page with Nested Selection",
          content: %{
            "model" => [
              %{
                "type" => "selection",
                "id" => "test-selection-nested",
                "count" => 3,
                "logic" => %{
                  "conditions" => %{
                    "operator" => "any",
                    "children" => [
                      %{
                        "operator" => "all",
                        "children" => [
                          %{
                            "fact" => "objectives",
                            "operator" => "contains",
                            "value" => [objective1.resource_id]
                          }
                        ]
                      },
                      %{
                        "operator" => "all",
                        "children" => [
                          %{
                            "fact" => "objectives",
                            "operator" => "contains",
                            "value" => [objective2.resource_id]
                          }
                        ]
                      }
                    ]
                  }
                }
              }
            ]
          }
        })

      # Add resources to project and publication
      publication = Oli.Publishing.project_working_publication(project.slug)

      insert(:project_resource, %{
        project_id: project.id,
        resource_id: objective1.resource.id
      })

      insert(:project_resource, %{
        project_id: project.id,
        resource_id: objective2.resource.id
      })

      insert(:project_resource, %{
        project_id: project.id,
        resource_id: page_revision.resource.id
      })

      insert(:published_resource, %{
        publication: publication,
        resource: objective1.resource,
        revision: objective1,
        author: hd(project.authors)
      })

      insert(:published_resource, %{
        publication: publication,
        resource: objective2.resource,
        revision: objective2,
        author: hd(project.authors)
      })

      insert(:published_resource, %{
        publication: publication,
        resource: page_revision.resource,
        revision: page_revision,
        author: hd(project.authors)
      })

      # Store original IDs for verification
      original_objective1_id = objective1.resource_id
      original_objective2_id = objective2.resource_id

      # Export the project
      export =
        Export.export(project)
        |> unzip_to_memory()
        |> Enum.reduce(%{}, fn {f, c}, m -> Map.put(m, f, c) end)

      # Verify export has IDs (ints as currently emitted)
      page_file = "#{page_revision.resource_id}.json"
      {:ok, page_json} = Jason.decode(Map.get(export, String.to_charlist(page_file)))

      [exported_selection] =
        page_json["content"]["model"]
        |> Enum.filter(&(&1["type"] == "selection"))

      exported_logic = exported_selection["logic"]
      [exported_first_clause, exported_second_clause] = exported_logic["conditions"]["children"]

      [exported_first_expr] = exported_first_clause["children"]
      [exported_second_expr] = exported_second_clause["children"]

      assert exported_first_expr["value"] == [original_objective1_id]
      assert exported_second_expr["value"] == [original_objective2_id]

      # Import the project back
      {:ok, imported_project} = Oli.Interop.Ingest.process(export, author)

      # Find the imported page by title
      imported_page =
        AuthoringResolver.from_title(imported_project.slug, "Test Page with Nested Selection")

      assert length(imported_page) == 1
      imported_page_revision = hd(imported_page)

      # Verify the bank selection with nested clauses is preserved in the imported project
      content = imported_page_revision.content

      [imported_selection] =
        content["model"]
        |> Enum.filter(&(&1["type"] == "selection"))

      assert imported_selection["id"] == "test-selection-nested"
      assert imported_selection["count"] == 3

      # Verify nested logic structure is preserved
      imported_logic = imported_selection["logic"]
      assert imported_logic["conditions"]["operator"] == "any"
      assert length(imported_logic["conditions"]["children"]) == 2

      [imported_first_clause, imported_second_clause] = imported_logic["conditions"]["children"]

      # Verify first nested clause
      assert imported_first_clause["operator"] == "all"
      assert length(imported_first_clause["children"]) == 1
      [imported_first_expr] = imported_first_clause["children"]
      assert imported_first_expr["fact"] == "objectives"
      assert imported_first_expr["operator"] == "contains"
      assert is_list(imported_first_expr["value"])
      assert length(imported_first_expr["value"]) == 1

      # Verify the objective ID is correctly mapped to new resource ID (integer)
      [imported_objective1_id] = imported_first_expr["value"]
      assert is_integer(imported_objective1_id)

      # Verify second nested clause
      assert imported_second_clause["operator"] == "all"
      assert length(imported_second_clause["children"]) == 1
      [imported_second_expr] = imported_second_clause["children"]
      assert imported_second_expr["fact"] == "objectives"
      assert imported_second_expr["operator"] == "contains"
      assert is_list(imported_second_expr["value"])
      assert length(imported_second_expr["value"]) == 1

      # Verify the objective ID is correctly mapped to new resource ID (integer)
      [imported_objective2_id] = imported_second_expr["value"]
      assert is_integer(imported_objective2_id)

      # Find the imported objectives to verify IDs are correct
      imported_objectives =
        Oli.Publishing.get_unpublished_revisions_by_type(imported_project.slug, "objective")
        |> Enum.filter(fn obj -> obj.title in ["Objective 1", "Objective 2"] end)

      assert length(imported_objectives) == 2
      imported_objective_resource_ids = Enum.map(imported_objectives, & &1.resource_id)

      # Verify the objective IDs in the selection match the imported objectives
      assert imported_objective1_id in imported_objective_resource_ids
      assert imported_objective2_id in imported_objective_resource_ids
      assert imported_objective1_id != imported_objective2_id
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
