defmodule Oli.Versioning.RevisionTree.TreeTest do

  use ExUnit.Case, async: true

  alias Oli.Versioning.RevisionTree.Tree

  def as_revisions(ids), do: Enum.map(ids, fn t -> rev(t) end)

  def rev({p, id}), do: %{id: id, previous_revision_id: p}

  def proj({p, id}), do: %{id: id, parent_project_id: p}

  describe "project sorting by parent tree" do

    test "it sorts several forked projects correctly" do

      #     2 - 5
      #   /
      # 1 - 3 - 6 - 7
      #   \      \
      #     4       8

      projects = [
        proj({nil, 1}),
        proj({1, 2}),
        proj({1, 3}),
        proj({1, 4}),
        proj({2, 5}),
        proj({3, 6}),
        proj({6, 7}),
        proj({6, 8})
      ]

      assert [1, 2, 5, 3, 6, 7, 8, 4] = Tree.sort_preorder(projects)
      |> Enum.map(fn p -> p.id end)

    end

  end

  describe "tree construction" do

    test "it works on a simple linked list" do

      # Constructs the following:
      #
      # 1-2-3-4-5
      #         ^
      #         |
      #         proj1
      revisions = [{nil,1}, {1, 2}, {2, 3}, {3, 4}, {4, 5}] |> as_revisions

      tree_nodes = Tree.build(revisions, [rev({4,5})], [proj({nil, 1})])

      assert Enum.to_list(tree_nodes) |> length() == 5

      assert Map.get(tree_nodes, 1).revision.id == 1
      assert Map.get(tree_nodes, 1).project_id == 1
      assert [%{revision: %{id: 2}}] = Map.get(tree_nodes, 1).children

      assert Map.get(tree_nodes, 5).revision.id == 5
      assert [] = Map.get(tree_nodes, 5).children

    end

    test "it works on a simple linked list, multiple projects at same head" do

      # Constructs the following:
      #
      #         proj2
      #         |
      # 1-2-3-4-5
      #         ^
      #         |
      #         proj1
      #
      # Simulating that proj2 forked from the head revision of proj1, and neither
      # have created new revisions since that fork

      revisions = [{nil,1}, {1, 2}, {2, 3}, {3, 4}, {4, 5}] |> as_revisions
      tree_nodes = Tree.build(revisions, [rev({4,5}), rev({4,5})], [proj({nil, 1}), proj({1, 2})])

      assert Enum.to_list(tree_nodes) |> length() == 5

      assert Map.get(tree_nodes, 1).revision.id == 1
      assert [%{revision: %{id: 2}}] = Map.get(tree_nodes, 1).children

      assert Map.get(tree_nodes, 5).revision.id == 5
      assert Map.get(tree_nodes, 5).project_id == 1
      assert [] = Map.get(tree_nodes, 5).children

    end

    test "it works on a simple linked list, multiple projects" do

      # Constructs the following:
      #
      # 1-2-3-4-5
      # ^       ^
      # |       |
      # proj2   proj1
      #
      # Simulating that proj2 forked from the initial revision, never edited that revision,
      # and proj1 have several other revisions added afterwards

      revisions = [{nil,1}, {1, 2}, {2, 3}, {3, 4}, {4, 5}] |> as_revisions

      tree_nodes = Tree.build(revisions, [rev({4,5}), rev({nil, 1})], [proj({nil, 1}), proj({1, 2})])

      assert Enum.to_list(tree_nodes) |> length() == 5

      assert Map.get(tree_nodes, 1).revision.id == 1
      assert Map.get(tree_nodes, 1).project_id == 1
      assert [%{revision: %{id: 2}}] = Map.get(tree_nodes, 1).children

      assert Map.get(tree_nodes, 5).revision.id == 5
      assert Map.get(tree_nodes, 5).project_id == 1
      assert [] = Map.get(tree_nodes, 5).children

    end

    test "it works on a two path fork" do

      # Constructs the following:
      #
      # 1-2-3-4-5  <- proj1
      #      \
      #       6-7-8  <- proj2
      revisions = [{nil,1}, {1, 2}, {2, 3}, {3, 4}, {4, 5},
                             {3, 6}, {6, 7}, {7, 8}] |> as_revisions

      tree_nodes = Tree.build(revisions, [rev({4,5}), rev({7, 8})], [proj({nil, 1}), proj({1, 2})])

      assert Enum.to_list(tree_nodes) |> length() == 8

      # Verify the root node
      assert Map.get(tree_nodes, 1).revision.id == 1
      assert [%{revision: %{id: 2}}] = Map.get(tree_nodes, 1).children

      # Verify the leaf nodes
      assert Map.get(tree_nodes, 5).revision.id == 5
      assert [] = Map.get(tree_nodes, 5).children

      assert Map.get(tree_nodes, 8).revision.id == 8
      assert [] = Map.get(tree_nodes, 8).children

      # Verify the forked node
      node3 = Map.get(tree_nodes, 3)
      assert [%{revision: %{id: 4}}, %{revision: %{id: 6}}] = node3.children

    end

    test "it works on a three path fork" do

      # Constructs the following:
      #       9-10  <- proj3
      #      /
      # 1-2-3-4-5  <- proj1
      #      \
      #       6-7-8  <- proj2
      revisions = [{nil,1}, {1, 2}, {2, 3}, {3, 4}, {4, 5}, {3, 6}, {6, 7}, {7, 8}, {3, 9}, {9, 10}] |> as_revisions

      p1 = proj({nil, 1})
      p2 = proj({1, 2})
      p3 = proj({1, 3})

      tree_nodes = Tree.build(revisions, [rev({4, 5}), rev({7, 8}), rev({9, 10})], [p1, p2, p3])

      assert Enum.to_list(tree_nodes) |> length() == 10

      # Verify the root node
      assert Map.get(tree_nodes, 1).revision.id == 1
      assert Map.get(tree_nodes, 1).project_id == 1
      assert [%{revision: %{id: 2}}] = Map.get(tree_nodes, 1).children

      # Verify the leaf nodes
      assert Map.get(tree_nodes, 5).revision.id == 5
      assert Map.get(tree_nodes, 5).project_id == 1
      assert [] = Map.get(tree_nodes, 5).children

      assert Map.get(tree_nodes, 8).revision.id == 8
      assert Map.get(tree_nodes, 8).project_id == 2
      assert [] = Map.get(tree_nodes, 8).children

      assert Map.get(tree_nodes, 10).revision.id == 10
      assert Map.get(tree_nodes, 10).project_id == 3
      assert [] = Map.get(tree_nodes, 10).children

      # Verify the forked node
      node3 = Map.get(tree_nodes, 3)
      assert node3.project_id == 1
      assert [%{revision: %{id: 4}}, %{revision: %{id: 6}}, %{revision: %{id: 9}}] = node3.children

    end

    test "it works on a fork off a fork" do

      # Constructs the following:
      #
      # 1-2-3-4-5  <- proj1
      #      \
      #       6-7-8  <- proj2
      #        \
      #         9-10  <- proj3
      revisions = [{nil,1}, {1, 2}, {2, 3}, {3, 4}, {4, 5}, {3, 6}, {6, 7}, {7, 8}, {6, 9}, {9, 10}] |> as_revisions

      p1 = proj({nil, 1})
      p2 = proj({1, 2})
      p3 = proj({1, 3})

      tree_nodes = Tree.build(revisions, [rev({4, 5}), rev({7, 8}), rev({9, 10})], [p1, p2, p3])

      assert Enum.to_list(tree_nodes) |> length() == 10

      # Verify the root node
      assert Map.get(tree_nodes, 1).revision.id == 1
      assert Map.get(tree_nodes, 1).project_id == 1
      assert [%{revision: %{id: 2}}] = Map.get(tree_nodes, 1).children

      # Verify the leaf nodes
      assert Map.get(tree_nodes, 5).revision.id == 5
      assert Map.get(tree_nodes, 5).project_id == 1
      assert [] = Map.get(tree_nodes, 5).children

      assert Map.get(tree_nodes, 8).revision.id == 8
      assert Map.get(tree_nodes, 8).project_id == 2
      assert [] = Map.get(tree_nodes, 8).children

      assert Map.get(tree_nodes, 10).revision.id == 10
      assert Map.get(tree_nodes, 10).project_id == 3
      assert [] = Map.get(tree_nodes, 10).children

      # Verify the forked nodes
      node3 = Map.get(tree_nodes, 3)
      assert node3.project_id == 1
      assert [%{revision: %{id: 4}}, %{revision: %{id: 6}}] = node3.children

      node6 = Map.get(tree_nodes, 6)
      assert node6.project_id == 2
      assert [%{revision: %{id: 7}}, %{revision: %{id: 9}}] = node6.children

    end

  end


end
