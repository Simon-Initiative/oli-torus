defmodule Oli.Delivery.InstructorCustomizationsTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.InstructorCustomizations
  alias Oli.Delivery.InstructorCustomizations.ActivityExclusion
  alias Oli.Delivery.InstructorCustomizations.PageExclusions
  alias Oli.Delivery.Sections.SectionResource
  alias Oli.Publishing.PublishedResource
  alias Oli.Repo
  alias Oli.Resources.Revision

  setup do
    %{
      section: insert(:section),
      other_section: insert(:section),
      page_resource: insert(:resource),
      other_page_resource: insert(:resource),
      activity_resource: insert(:resource),
      candidate_resource: insert(:resource)
    }
  end

  describe "page exclusion reads" do
    test "returns only raw exclusions for the requested section and page", context do
      embedded = insert_exclusion(context, :embedded_activity)
      insert_exclusion(context, :bank_selection, section_id: context.other_section.id)
      insert_exclusion(context, :bank_candidate, page_resource_id: context.other_page_resource.id)

      assert InstructorCustomizations.get_page_exclusions(
               context.section,
               context.page_resource.id
             ) == [embedded]
    end

    test "builds a compact mixed-kind page view", context do
      insert_exclusion(context, :embedded_activity)
      insert_exclusion(context, :bank_selection)
      insert_exclusion(context, :bank_candidate)

      assert %PageExclusions{
               section_id: section_id,
               page_resource_id: page_resource_id,
               excluded_activity_ids: excluded_activity_ids,
               excluded_selection_ids: excluded_selection_ids,
               excluded_bank_candidate_ids_by_selection: candidates
             } =
               InstructorCustomizations.get_page_exclusion_view(
                 context.section.id,
                 context.page_resource.id
               )

      assert section_id == context.section.id
      assert page_resource_id == context.page_resource.id
      assert excluded_activity_ids == MapSet.new([context.activity_resource.id])
      assert excluded_selection_ids == MapSet.new(["selection-1"])
      assert candidates == %{"selection-1" => MapSet.new([context.candidate_resource.id])}
    end

    test "returns an empty page view when no exclusions exist", context do
      assert InstructorCustomizations.get_page_exclusion_view(
               context.section,
               context.page_resource.id
             ) == PageExclusions.empty(context.section.id, context.page_resource.id)
    end

    test "persists exclusions without changing authored or section-resource records", context do
      before_counts = %{
        revisions: Repo.aggregate(Revision, :count),
        published_resources: Repo.aggregate(PublishedResource, :count),
        section_resources: Repo.aggregate(SectionResource, :count)
      }

      insert_exclusion(context, :embedded_activity)

      assert %{
               revisions: Repo.aggregate(Revision, :count),
               published_resources: Repo.aggregate(PublishedResource, :count),
               section_resources: Repo.aggregate(SectionResource, :count)
             } == before_counts
    end

    test "loads the page view with one repository query", context do
      insert_exclusion(context, :embedded_activity)
      handler_id = "instructor-customizations-query-count-#{System.unique_integer([:positive])}"
      parent = self()

      :telemetry.attach(
        handler_id,
        [:oli, :repo, :query],
        fn _, _, metadata, _ ->
          if metadata.source == "section_page_activity_exclusions" do
            send(parent, :repo_query)
          end
        end,
        %{}
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      InstructorCustomizations.get_page_exclusion_view(context.section, context.page_resource.id)

      assert_receive :repo_query
      refute_receive :repo_query
    end
  end

  describe "duplicate_section_exclusions/2" do
    test "copies all exclusion kinds from one section to another", context do
      destination_section = insert(:section)

      insert_exclusion(context, :embedded_activity)
      insert_exclusion(context, :bank_selection)
      insert_exclusion(context, :bank_candidate)

      assert {:ok, 3} =
               InstructorCustomizations.duplicate_section_exclusions(
                 context.section,
                 destination_section
               )

      assert %PageExclusions{
               section_id: section_id,
               page_resource_id: page_resource_id,
               excluded_activity_ids: excluded_activity_ids,
               excluded_selection_ids: excluded_selection_ids,
               excluded_bank_candidate_ids_by_selection: candidates
             } =
               InstructorCustomizations.get_page_exclusion_view(
                 destination_section,
                 context.page_resource.id
               )

      assert section_id == destination_section.id
      assert page_resource_id == context.page_resource.id
      assert excluded_activity_ids == MapSet.new([context.activity_resource.id])
      assert excluded_selection_ids == MapSet.new(["selection-1"])
      assert candidates == %{"selection-1" => MapSet.new([context.candidate_resource.id])}

      assert length(
               InstructorCustomizations.get_page_exclusions(
                 context.section,
                 context.page_resource.id
               )
             ) == 3
    end

    test "is idempotent for the same destination section", context do
      destination_section = insert(:section)

      insert_exclusion(context, :embedded_activity)

      assert {:ok, 1} =
               InstructorCustomizations.duplicate_section_exclusions(
                 context.section.id,
                 destination_section.id
               )

      assert {:ok, 0} =
               InstructorCustomizations.duplicate_section_exclusions(
                 context.section.id,
                 destination_section.id
               )

      assert [
               %ActivityExclusion{
                 section_id: section_id,
                 page_resource_id: page_resource_id,
                 kind: :embedded_activity,
                 excluded_resource_id: excluded_resource_id
               }
             ] =
               InstructorCustomizations.get_page_exclusions(
                 destination_section.id,
                 context.page_resource.id
               )

      assert section_id == destination_section.id
      assert page_resource_id == context.page_resource.id
      assert excluded_resource_id == context.activity_resource.id
    end
  end

  describe "predicate helpers" do
    test "answers enabled state from the page view", context do
      view =
        PageExclusions.new(context.section.id, context.page_resource.id, [
          exclusion(context, :embedded_activity),
          exclusion(context, :bank_selection),
          exclusion(context, :bank_candidate)
        ])

      refute InstructorCustomizations.activity_enabled?(view, context.activity_resource.id)
      assert InstructorCustomizations.activity_enabled?(view, context.candidate_resource.id)

      refute InstructorCustomizations.bank_selection_enabled?(view, "selection-1")
      assert InstructorCustomizations.bank_selection_enabled?(view, "selection-2")

      refute InstructorCustomizations.bank_candidate_enabled?(
               view,
               "selection-1",
               context.candidate_resource.id
             )

      assert InstructorCustomizations.bank_candidate_enabled?(
               view,
               "selection-2",
               context.candidate_resource.id
             )
    end
  end

  defp insert_exclusion(context, kind, overrides \\ []) do
    context
    |> exclusion_attrs(kind)
    |> Map.merge(Map.new(overrides))
    |> then(
      &ActivityExclusion.changeset(
        %ActivityExclusion{},
        &1.section_id,
        &1.page_resource_id,
        Map.drop(&1, [:section_id, :page_resource_id])
      )
    )
    |> Repo.insert!()
  end

  defp exclusion(context, kind) do
    struct!(ActivityExclusion, exclusion_attrs(context, kind))
  end

  defp exclusion_attrs(context, :embedded_activity) do
    %{
      section_id: context.section.id,
      page_resource_id: context.page_resource.id,
      kind: :embedded_activity,
      excluded_resource_id: context.activity_resource.id
    }
  end

  defp exclusion_attrs(context, :bank_selection) do
    %{
      section_id: context.section.id,
      page_resource_id: context.page_resource.id,
      kind: :bank_selection,
      selection_id: "selection-1"
    }
  end

  defp exclusion_attrs(context, :bank_candidate) do
    %{
      section_id: context.section.id,
      page_resource_id: context.page_resource.id,
      kind: :bank_candidate,
      selection_id: "selection-1",
      excluded_resource_id: context.candidate_resource.id
    }
  end
end
