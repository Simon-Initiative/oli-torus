defmodule Oli.Versioning.RevisionTree.TreeTest do

  use ExUnit.Case, async: true

  alias Oli.Versioning.RevisionTree.Tree

  def as_revisions(ids), do: Enum.map(ids, fn t -> rev(t) end)

  def rev({p, id}), do: %{id: id, previous_revision_id: p}

  describe "tree construction" do

    test "it works on a simple linked list" do

      revisions = [{4, 5}, {nil,1}, {1, 2}, {2, 3}, {3, 4}] |> as_revisions
      project = %{id: 1}

      tree_nodes = Tree.build(revisions, [hd(revisions)], [project])

      assert Enum.to_list(tree_nodes) |> length() == 5

      assert Map.get(tree_nodes, 1).revision.id == 1
      assert [%{revision: %{id: 2}}] = Map.get(tree_nodes, 1).children

      assert Map.get(tree_nodes, 5).revision.id == 5
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

      revisions = [{4, 5}, {1, 2}, {2, 3}, {3, 4}, {nil,1}] |> as_revisions
      project1 = %{id: 1}
      project2 = %{id: 2}

      tree_nodes = Tree.build(revisions, [hd(revisions), List.last(revisions)], [project1, project2])

      assert Enum.to_list(tree_nodes) |> length() == 5

      assert Map.get(tree_nodes, 1).revision.id == 1
      assert [%{revision: %{id: 2}}] = Map.get(tree_nodes, 1).children

      assert Map.get(tree_nodes, 5).revision.id == 5
      assert [] = Map.get(tree_nodes, 5).children

    end

    test "it works on a two path fork" do

      # Constructs the following:
      #
      # 1-2-3-4-5
      #      \
      #       6-7-8
      revisions = [{4, 5}, {nil,1}, {1, 2}, {2, 3}, {3, 4}, {3, 6}, {6, 7}, {7, 8}] |> as_revisions

      project1 = %{id: 1}
      project2 = %{id: 2}

      tree_nodes = Tree.build(revisions, [hd(revisions), List.last(revisions)], [project1, project2])

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
      #       9-10
      #      /
      # 1-2-3-4-5
      #      \
      #       6-7-8
      revisions = [{4, 5}, {nil,1}, {1, 2}, {2, 3}, {3, 4}, {3, 6}, {6, 7}, {7, 8}, {3, 9}, {9, 10}] |> as_revisions

      p1 = %{id: 1}
      p2 = %{id: 2}
      p3 = %{id: 3}

      tree_nodes = Tree.build(revisions, [rev({4, 5}), rev({9, 10}), rev({7, 8})], [p1, p2, p3])

      assert Enum.to_list(tree_nodes) |> length() == 10

      # Verify the root node
      assert Map.get(tree_nodes, 1).revision.id == 1
      assert [%{revision: %{id: 2}}] = Map.get(tree_nodes, 1).children

      # Verify the leaf nodes
      assert Map.get(tree_nodes, 5).revision.id == 5
      assert [] = Map.get(tree_nodes, 5).children

      assert Map.get(tree_nodes, 8).revision.id == 8
      assert [] = Map.get(tree_nodes, 8).children

      assert Map.get(tree_nodes, 10).revision.id == 10
      assert [] = Map.get(tree_nodes, 10).children

      # Verify the forked node
      node3 = Map.get(tree_nodes, 3)
      assert [%{revision: %{id: 4}}, %{revision: %{id: 9}}, %{revision: %{id: 6}}] = node3.children

    end

    test "it works on a fork off a fork" do

      # Constructs the following:
      #
      # 1-2-3-4-5
      #      \
      #       6-7-8
      #        \
      #         9-10
      revisions = [{4, 5}, {nil,1}, {1, 2}, {2, 3}, {3, 4}, {3, 6}, {6, 7}, {7, 8}, {6, 9}, {9, 10}] |> as_revisions

      p1 = %{id: 1}
      p2 = %{id: 2}
      p3 = %{id: 3}

      tree_nodes = Tree.build(revisions, [rev({4, 5}), rev({7, 8}), rev({9, 10})], [p1, p2, p3])

      assert Enum.to_list(tree_nodes) |> length() == 10

      # Verify the root node
      assert Map.get(tree_nodes, 1).revision.id == 1
      assert [%{revision: %{id: 2}}] = Map.get(tree_nodes, 1).children

      # Verify the leaf nodes
      assert Map.get(tree_nodes, 5).revision.id == 5
      assert [] = Map.get(tree_nodes, 5).children

      assert Map.get(tree_nodes, 8).revision.id == 8
      assert [] = Map.get(tree_nodes, 8).children

      assert Map.get(tree_nodes, 10).revision.id == 10
      assert [] = Map.get(tree_nodes, 10).children

      # Verify the forked nodes
      node3 = Map.get(tree_nodes, 3)
      assert [%{revision: %{id: 4}}, %{revision: %{id: 6}}] = node3.children

      node6 = Map.get(tree_nodes, 6)
      assert [%{revision: %{id: 7}}, %{revision: %{id: 9}}] = node6.children

    end



  end


end
