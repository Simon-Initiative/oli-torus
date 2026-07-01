defmodule Oli.Delivery.InstructorCustomizations.ActivityExclusionTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.InstructorCustomizations.ActivityExclusion
  alias Oli.Repo

  describe "changeset/2" do
    setup do
      %{
        section: insert(:section),
        page_resource: insert(:resource),
        activity_resource: insert(:resource)
      }
    end

    test "accepts each valid exclusion kind", context do
      assert valid_changeset?(context, %{
               kind: :embedded_activity,
               excluded_resource_id: context.activity_resource.id
             })

      assert valid_changeset?(context, %{
               kind: :bank_selection,
               selection_id: "selection-1"
             })

      assert valid_changeset?(context, %{
               kind: :bank_candidate,
               selection_id: "selection-1",
               excluded_resource_id: context.activity_resource.id
             })
    end

    test "rejects invalid field combinations", context do
      embedded_missing_resource =
        changeset(context, %{
          kind: :embedded_activity
        })

      embedded =
        changeset(context, %{
          kind: :embedded_activity,
          selection_id: "selection-1",
          excluded_resource_id: context.activity_resource.id
        })

      bank_selection_missing_selection =
        changeset(context, %{
          kind: :bank_selection
        })

      bank_selection =
        changeset(context, %{
          kind: :bank_selection,
          selection_id: "selection-1",
          excluded_resource_id: context.activity_resource.id
        })

      bank_candidate_missing_selection =
        changeset(context, %{
          kind: :bank_candidate,
          excluded_resource_id: context.activity_resource.id
        })

      bank_candidate =
        changeset(context, %{
          kind: :bank_candidate,
          selection_id: "selection-1"
        })

      missing_kind = changeset(context, %{})

      assert "can't be blank" in errors_on(embedded_missing_resource).excluded_resource_id
      assert "must be empty for this exclusion kind" in errors_on(embedded).selection_id
      assert "can't be blank" in errors_on(bank_selection_missing_selection).selection_id

      assert "must be empty for this exclusion kind" in errors_on(bank_selection).excluded_resource_id

      assert "can't be blank" in errors_on(bank_candidate_missing_selection).selection_id
      assert "can't be blank" in errors_on(bank_candidate).excluded_resource_id
      assert "can't be blank" in errors_on(missing_kind).kind
    end

    test "database constraints reject duplicate active exclusions", context do
      attrs = base_attrs(context)

      for target <- [
            %{kind: :embedded_activity, excluded_resource_id: context.activity_resource.id},
            %{kind: :bank_selection, selection_id: "selection-1"},
            %{
              kind: :bank_candidate,
              selection_id: "selection-1",
              excluded_resource_id: context.activity_resource.id
            }
          ] do
        attrs = Map.merge(attrs, target)

        assert {:ok, _} =
                 %ActivityExclusion{}
                 |> ActivityExclusion.changeset(
                   context.section.id,
                   context.page_resource.id,
                   attrs
                 )
                 |> Repo.insert()

        assert {:error, changeset} =
                 %ActivityExclusion{}
                 |> ActivityExclusion.changeset(
                   context.section.id,
                   context.page_resource.id,
                   attrs
                 )
                 |> Repo.insert()

        assert errors_on(changeset) != %{}
      end
    end

    test "uniqueness scope allows the same targets in other sections, pages, and selections",
         context do
      other_section = insert(:section)
      other_page = insert(:resource)

      for {section_id, page_resource_id} <- [
            {context.section.id, context.page_resource.id},
            {other_section.id, context.page_resource.id},
            {context.section.id, other_page.id}
          ] do
        assert {:ok, _} =
                 insert_exclusion(
                   section_id,
                   page_resource_id,
                   %{
                     kind: :embedded_activity,
                     excluded_resource_id: context.activity_resource.id
                   }
                 )
      end

      for selection_id <- ["selection-1", "selection-2"] do
        assert {:ok, _} =
                 insert_exclusion(
                   context.section.id,
                   context.page_resource.id,
                   %{
                     kind: :bank_candidate,
                     selection_id: selection_id,
                     excluded_resource_id: context.activity_resource.id
                   }
                 )
      end
    end

    test "database shape constraint rejects invalid rows without a changeset", context do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      assert_raise Postgrex.Error, fn ->
        Repo.insert_all(ActivityExclusion, [
          %{
            section_id: context.section.id,
            page_resource_id: context.page_resource.id,
            kind: :embedded_activity,
            selection_id: "selection-1",
            excluded_resource_id: context.activity_resource.id,
            inserted_at: now,
            updated_at: now
          }
        ])
      end
    end

    test "does not allow attrs to override the trusted section and page scope", context do
      other_section = insert(:section)
      other_page = insert(:resource)

      changeset =
        ActivityExclusion.changeset(
          %ActivityExclusion{},
          context.section.id,
          context.page_resource.id,
          %{
            section_id: other_section.id,
            page_resource_id: other_page.id,
            kind: :embedded_activity,
            excluded_resource_id: context.activity_resource.id
          }
        )

      assert get_change(changeset, :section_id) == context.section.id
      assert get_change(changeset, :page_resource_id) == context.page_resource.id
    end
  end

  defp valid_changeset?(context, attrs), do: changeset(context, attrs).valid?

  defp insert_exclusion(section_id, page_resource_id, attrs) do
    %ActivityExclusion{}
    |> ActivityExclusion.changeset(section_id, page_resource_id, attrs)
    |> Repo.insert()
  end

  defp changeset(context, attrs) do
    ActivityExclusion.changeset(
      %ActivityExclusion{},
      context.section.id,
      context.page_resource.id,
      attrs
    )
  end

  defp base_attrs(_context), do: %{}
end
