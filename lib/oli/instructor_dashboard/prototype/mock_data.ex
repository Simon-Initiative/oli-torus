defmodule Oli.InstructorDashboard.Prototype.MockData do
  @moduledoc """
  Deterministic, in-memory data used by the prototype oracles.
  """

  @units [
    %{
      id: 1,
      title: "Unit 1",
      children: [
        %{id: 101, title: "Module 1A", resource_type: :module},
        %{id: 1001, title: "Intro Page", resource_type: :page},
        %{id: 102, title: "Module 1B", resource_type: :module}
      ]
    },
    %{
      id: 2,
      title: "Unit 2",
      children: [
        %{id: 201, title: "Module 2A", resource_type: :module},
        %{id: 202, title: "Module 2B", resource_type: :module}
      ]
    },
    %{
      id: 3,
      title: "Unit 3",
      children: [
        %{id: 301, title: "Module 3A", resource_type: :module},
        %{id: 302, title: "Module 3B", resource_type: :module}
      ]
    },
    %{
      id: 4,
      title: "Unit 4",
      children: [
        %{id: 401, title: "Module 4A", resource_type: :module},
        %{id: 402, title: "Module 4B", resource_type: :module}
      ]
    },
    %{
      id: 5,
      title: "Unit 5",
      children: [
        %{id: 501, title: "Module 5A", resource_type: :module},
        %{id: 502, title: "Module 5B", resource_type: :module}
      ]
    },
    %{
      id: 6,
      title: "Unit 6",
      children: [
        %{id: 601, title: "Module 6A", resource_type: :module},
        %{id: 602, title: "Module 6B", resource_type: :module}
      ]
    }
  ]

  @module_children %{
    101 => [
      %{id: 10_101, title: "Practice Page", resource_type: :page},
      %{id: 10_102, title: "Quiz Page", resource_type: :page}
    ],
    102 => [%{id: 10_103, title: "Review Page", resource_type: :page}],
    201 => [%{id: 20_101, title: "Page 2A-1", resource_type: :page}],
    202 => [%{id: 20_201, title: "Page 2B-1", resource_type: :page}],
    301 => [%{id: 30_101, title: "Page 3A-1", resource_type: :page}],
    302 => [%{id: 30_201, title: "Page 3B-1", resource_type: :page}],
    401 => [%{id: 40_101, title: "Page 4A-1", resource_type: :page}],
    402 => [%{id: 40_201, title: "Page 4B-1", resource_type: :page}],
    501 => [%{id: 50_101, title: "Page 5A-1", resource_type: :page}],
    502 => [%{id: 50_201, title: "Page 5B-1", resource_type: :page}],
    601 => [%{id: 60_101, title: "Page 6A-1", resource_type: :page}],
    602 => [%{id: 60_201, title: "Page 6B-1", resource_type: :page}]
  }

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
    |> Map.get(:children, [])
    |> Enum.filter(&(&1.resource_type == :module))
  end

  def module_ids do
    @units
    |> Enum.flat_map(fn unit ->
      unit.children
      |> Enum.filter(&(&1.resource_type == :module))
      |> Enum.map(& &1.id)
    end)
  end

  def direct_children(:course, nil), do: units()

  def direct_children(:unit, unit_id) do
    @units
    |> Enum.find(&(&1.id == unit_id))
    |> Map.get(:children, [])
  end

  def direct_children(:module, module_id) do
    Map.get(@module_children, module_id, [])
  end

  def direct_children(_, _), do: []

  def resource_type(:course), do: :course
  def resource_type(:unit), do: :unit
  def resource_type(:module), do: :module
  def resource_type(:page), do: :page

  def pages_for_module(module_id) do
    Map.get(@module_children, module_id, [])
  end

  def direct_page_ids do
    @units
    |> Enum.flat_map(fn unit ->
      unit.children
      |> Enum.filter(&(&1.resource_type == :page))
      |> Enum.map(& &1.id)
    end)
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
