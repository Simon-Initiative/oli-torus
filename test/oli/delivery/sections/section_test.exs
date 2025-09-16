defmodule Oli.Delivery.Sections.SectionTest do
  use Oli.DataCase

  import Oli.Factory

  alias Oli.Delivery.Sections.Section

  @valid_section_attrs %{
    type: :enrollable,
    title: "Section Title",
    registration_open: true,
    base_project_id: 1,
    start_date: nil,
    end_date: nil
  }

  describe "changeset/2" do
    for required_field <- Section.required_fields() do
      @required_field required_field
      test "validates #{required_field} is required" do
        attrs = Map.put(@valid_section_attrs, @required_field, nil)
        changeset = Section.changeset(%Section{}, attrs)

        assert changeset.errors[@required_field] == {"can't be blank", [validation: :required]}
      end
    end

    test "validates publisher_id is required if it is a product" do
      section = build(:section, @valid_section_attrs)
      changeset = Section.changeset(section, %{type: :blueprint, publisher_id: nil})

      assert changeset.errors[:publisher_id] == {"can't be blank", [validation: :required]}
    end

    test "validates apply_major_updates is required if it is a product" do
      section = build(:section, @valid_section_attrs)
      changeset = Section.changeset(section, %{type: :blueprint, apply_major_updates: nil})

      assert changeset.errors[:apply_major_updates] == {"can't be blank", [validation: :required]}
    end

    test "validates positive grace period" do
      section = build(:section, @valid_section_attrs)

      changeset =
        Section.changeset(section, %{
          has_grace_period: true,
          requires_payment: true,
          grace_period_days: 0
        })

      assert changeset.errors[:grace_period_days] ==
               {"must be greater than or equal to one", []}
    end

    test "validates positive money" do
      section = build(:section, @valid_section_attrs)

      changeset =
        Section.changeset(section, %{requires_payment: true, amount: Money.new(-1, "USD")})

      assert changeset.errors[:amount] ==
               {"must be greater than or equal to one", []}
    end

    test "validates dates consistency" do
      # validate end_date
      section = build(:section, %{@valid_section_attrs | start_date: ~U[2024-01-01 00:00:00Z]})

      changeset = Section.changeset(section, %{end_date: ~U[2023-01-01 00:00:00Z]})

      assert changeset.errors[:end_date] ==
               {"must be after the start date", []}

      # validate start_date
      section = build(:section, %{@valid_section_attrs | end_date: ~U[2023-01-01 00:00:00Z]})

      changeset = Section.changeset(section, %{start_date: ~U[2024-01-01 00:00:00Z]})

      assert changeset.errors[:start_date] ==
               {"must be before the end date", []}
    end

    test "validates title length" do
      section = build(:section, @valid_section_attrs)

      changeset = Section.changeset(section, %{title: String.duplicate("a", 256)})

      assert changeset.errors[:title] |> elem(0) =~ ~r/should be at most .* character/
    end

    test "default assistant_enabled is false" do
      changeset =
        build(:section, @valid_section_attrs)
        |> Section.changeset()

      refute Ecto.Changeset.get_field(changeset, :assistant_enabled)
    end
  end
end
