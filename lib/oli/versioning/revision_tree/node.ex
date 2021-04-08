defmodule Oli.Versioning.RevisionTree.Node do
  @moduledoc """
  Struct representation of a node in a revision tree.
  """

  defstruct [:revision, :children, :project_id]
end
