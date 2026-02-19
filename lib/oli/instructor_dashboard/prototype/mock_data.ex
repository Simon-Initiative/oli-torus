defmodule Oli.InstructorDashboard.Prototype.MockData do
  @moduledoc """
  Deterministic, in-memory data used by the prototype oracles.
  """

  @units [
    %{
      id: 1,
      title: "Unit 1",
      modules: [%{id: 101, title: "Module 1A"}, %{id: 102, title: "Module 1B"}]
    },
    %{
      id: 2,
      title: "Unit 2",
      modules: [%{id: 201, title: "Module 2A"}, %{id: 202, title: "Module 2B"}]
    },
    %{
      id: 3,
      title: "Unit 3",
      modules: [%{id: 301, title: "Module 3A"}, %{id: 302, title: "Module 3B"}]
    },
    %{
      id: 4,
      title: "Unit 4",
      modules: [%{id: 401, title: "Module 4A"}, %{id: 402, title: "Module 4B"}]
    },
    %{
      id: 5,
      title: "Unit 5",
      modules: [%{id: 501, title: "Module 5A"}, %{id: 502, title: "Module 5B"}]
    },
    %{
      id: 6,
      title: "Unit 6",
      modules: [%{id: 601, title: "Module 6A"}, %{id: 602, title: "Module 6B"}]
    }
  ]

  @students [
    %{id: 1, name: "Michael Johnson", active: true},
    %{id: 2, name: "Emily Davis", active: true},
    %{id: 3, name: "James Smith", active: true},
    %{id: 4, name: "Sophia Brown", active: true},
    %{id: 5, name: "Daniel Garcia", active: true},
    %{id: 6, name: "Olivia Martinez", active: true},
    %{id: 7, name: "William Lee", active: false},
    %{id: 8, name: "Ava Wilson", active: true},
    %{id: 9, name: "Noah Clark", active: true},
    %{id: 10, name: "Isabella Lewis", active: false}
  ]

  def units do
    @units
  end

  def unit_ids do
    Enum.map(@units, & &1.id)
  end

  def modules_for_unit(unit_id) do
    @units
    |> Enum.find(&(&1.id == unit_id))
    |> Map.get(:modules, [])
  end

  def module_ids do
    @units
    |> Enum.flat_map(fn unit -> Enum.map(unit.modules, & &1.id) end)
  end

  def students do
    @students
  end

  def student_ids do
    Enum.map(@students, & &1.id)
  end

  def progress_percent(student_id, container_id) do
    rem(student_id * 13 + container_id * 7, 101)
  end

  def course_progress_percent(student_id) do
    unit_ids()
    |> Enum.map(&progress_percent(student_id, &1))
    |> average()
  end

  def progress_for_container(container_id, student_ids) do
    Map.new(student_ids, fn student_id ->
      {student_id, progress_percent(student_id, container_id)}
    end)
  end

  def proficiency_percent(student_id) do
    rem(student_id * 11 + 17, 101)
  end

  defp average([]), do: 0

  defp average(values) do
    values
    |> Enum.sum()
    |> Kernel./(length(values))
    |> round()
  end
end
