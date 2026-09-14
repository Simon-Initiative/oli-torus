defmodule Oli.Delivery.Sections.CopyOptionsTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Sections.CopyOptions

  describe "new/2" do
    test "accepts every known group" do
      assert {:ok, options} = CopyOptions.new(CopyOptions.groups())

      for group <- CopyOptions.groups() do
        assert CopyOptions.selected?(options, group)
      end
    end

    test "accepts a MapSet as well as a list" do
      assert {:ok, options} = CopyOptions.new(MapSet.new([:content, :schedule]))
      assert CopyOptions.selected?(options, :schedule)
      refute CopyOptions.selected?(options, :ai_settings)
    end

    test "rejects unknown groups rather than ignoring them" do
      assert {:error, {:unknown_copy_groups, [:grades]}} =
               CopyOptions.new([:content, :grades])
    end

    test "reports every unknown group, deduplicated" do
      assert {:error, {:unknown_copy_groups, unknown}} =
               CopyOptions.new([:content, :roster, :grades, :roster])

      assert Enum.sort(unknown) == [:grades, :roster]
    end

    test "requires content" do
      assert {:error, :content_group_required} = CopyOptions.new([:schedule])
      assert {:error, :content_group_required} = CopyOptions.new([])
    end

    test "content is required in the domain layer, not only in the UI" do
      # This is the check that keeps a future UI change from producing a copy
      # with no defined content source.
      assert {:error, :content_group_required} =
               CopyOptions.new([:section_settings, :assessment_settings, :ai_settings])
    end

    test "defaults to the allowlist section field policy" do
      assert {:ok, %CopyOptions{section_field_policy: :allowlist}} =
               CopyOptions.new([:content])
    end

    test "carries a project remap when given one" do
      assert {:ok, %CopyOptions{project_remap: {1, 2}}} =
               CopyOptions.new([:content], project_remap: {1, 2})
    end
  end

  describe "for_previous_section/1" do
    test "produces a previous-section, allowlisted policy with no remap" do
      assert {:ok, options} = CopyOptions.for_previous_section([:content, :schedule])

      assert options.source_kind == :previous_section
      assert options.section_field_policy == :allowlist
      assert options.project_remap == nil
    end

    test "applies the same validation as new/2" do
      assert {:error, :content_group_required} = CopyOptions.for_previous_section([:schedule])

      assert {:error, {:unknown_copy_groups, [:roster]}} =
               CopyOptions.for_previous_section([:content, :roster])
    end
  end

  describe "for_blueprint_duplication/1" do
    test "selects every group and inherits all section fields" do
      options = CopyOptions.for_blueprint_duplication()

      assert options.source_kind == :blueprint
      assert options.section_field_policy == :inherit_all

      for group <- CopyOptions.groups() do
        assert CopyOptions.selected?(options, group)
      end
    end

    test "carries the project remap used when cloning a project with products" do
      assert %CopyOptions{project_remap: {7, 9}} = CopyOptions.for_blueprint_duplication({7, 9})
    end
  end

  describe "to_audit_list/1" do
    test "returns sorted strings suitable for audit metadata" do
      {:ok, options} = CopyOptions.new([:schedule, :content])

      assert CopyOptions.to_audit_list(options) == ["content", "schedule"]
    end
  end
end
