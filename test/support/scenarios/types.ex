defmodule Oli.Scenarios.Types do
  defmodule ProjectSpec do
    defstruct [:title, :root]
  end

  defmodule Node do
    defstruct [:type, :title, children: []]
  end

  defmodule ScenarioSpec do
    defstruct [:dest_path, :source_path, :expected_structure, remix: [], ops: [], assertions: []]
  end

  defmodule BuiltProject do
    defstruct [:project, :working_pub, :root, :id_by_title, :rev_by_title]
  end

  defmodule RunResult do
    defstruct [:section, :publication, :final_hierarchy, :dest, :source]
  end
end