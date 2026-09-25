defmodule Oli.Delivery.Sections.LinkedActivities.PageContextsTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Sections.LinkedActivities.PageContexts

  test "missing page revisions produce an empty index" do
    assert PageContexts.from_activity_refs([%{resource_id: 100, revision_id: 9}], []) == %{}
  end

  test "indexes activity references by page and selects the first canonical context" do
    page_resources = [
      %{resource_id: 100, revision_id: 1},
      %{resource_id: 200, revision_id: 2}
    ]

    revisions = [
      %{id: 1, resource_id: 100, activity_refs: [7, 8]},
      %{id: 2, resource_id: 200, activity_refs: [7]}
    ]

    contexts = PageContexts.from_activity_refs(page_resources, revisions)

    assert Enum.map(contexts[7], & &1.page_resource_id) == [100, 200]
    assert contexts[8] |> List.first() |> Map.get(:page_resource_id) == 100
    assert PageContexts.canonical(contexts)[7].page_resource_id == 100
  end

  test "indexes recorded responses by page, dropping pages absent from the section" do
    page_resources = [
      %{resource_id: 100, revision_id: 1},
      %{resource_id: 200, revision_id: 2}
    ]

    revisions = [
      %{id: 1, resource_id: 100, activity_refs: []},
      %{id: 2, resource_id: 200, activity_refs: []}
    ]

    contexts =
      PageContexts.from_page_pairs(
        [{7, 100}, {7, 200}, {8, 100}, {9, 999}],
        page_resources,
        revisions
      )

    assert Enum.map(contexts[7], & &1.page_resource_id) == [100, 200]
    assert Enum.map(contexts[8], & &1.page_resource_id) == [100]
    refute Map.has_key?(contexts, 9)
    assert contexts[7] |> List.first() |> Map.get(:page_revision) |> Map.get(:id) == 1
  end

  test "the caller's pair order does not decide the canonical page" do
    page_resources = [
      %{resource_id: 100, revision_id: 1},
      %{resource_id: 200, revision_id: 2}
    ]

    revisions = [
      %{id: 1, resource_id: 100, activity_refs: []},
      %{id: 2, resource_id: 200, activity_refs: []}
    ]

    pairs = [{7, 100}, {7, 200}]

    forward = PageContexts.from_page_pairs(pairs, page_resources, revisions)
    reversed = PageContexts.from_page_pairs(Enum.reverse(pairs), page_resources, revisions)

    assert Enum.map(forward[7], & &1.page_resource_id) == [100, 200]
    assert Enum.map(reversed[7], & &1.page_resource_id) == [100, 200]
    assert PageContexts.canonical(reversed)[7].page_resource_id == 100
  end

  test "the depot's page order does not decide the canonical page either" do
    page_resources = [
      %{resource_id: 100, revision_id: 1},
      %{resource_id: 200, revision_id: 2}
    ]

    revisions = [
      %{id: 1, resource_id: 100, activity_refs: [7]},
      %{id: 2, resource_id: 200, activity_refs: [7]}
    ]

    forward = PageContexts.from_activity_refs(page_resources, revisions)
    reversed = PageContexts.from_activity_refs(Enum.reverse(page_resources), revisions)

    assert Enum.map(forward[7], & &1.page_resource_id) == [100, 200]
    assert Enum.map(reversed[7], & &1.page_resource_id) == [100, 200]
    assert PageContexts.canonical(reversed)[7].page_resource_id == 100
  end

  test "observed contexts lead, and a page present in both sources is not duplicated" do
    observed = %{
      7 => [%{page_resource_id: 200, page_revision: %{id: 2}}]
    }

    declared = %{
      7 => [
        %{page_resource_id: 100, page_revision: %{id: 1}},
        %{page_resource_id: 200, page_revision: %{id: 2}}
      ],
      8 => [%{page_resource_id: 100, page_revision: %{id: 1}}]
    }

    merged = PageContexts.merge(observed, declared)

    assert Enum.map(merged[7], & &1.page_resource_id) == [200, 100]
    assert PageContexts.canonical(merged)[7].page_resource_id == 200
    assert Enum.map(merged[8], & &1.page_resource_id) == [100]
  end
end
