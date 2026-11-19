defmodule Oli.Delivery.Sections.SectionFieldsTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Sections.{Section, SectionFields}

  @sets [
    audited: SectionFields.audited(),
    open: SectionFields.open(),
    lms_supplied: SectionFields.lms_supplied(),
    system_derived: SectionFields.system_derived()
  ]

  test "every section column is in exactly one set" do
    for column <- Section.__schema__(:fields) do
      sets = for {name, columns} <- @sets, column in columns, do: name

      assert length(sets) == 1,
             "#{column} must be classified in exactly one of audited, open, lms_supplied, " <>
               "or system_derived (found in #{inspect(sets)}); add it to a field policy of " <>
               "Oli.Auditing.EventCatalog.Fields or to the Section exclusions there"
    end
  end

  test "every classified field is a section column" do
    columns = Section.__schema__(:fields)

    for {name, set} <- @sets, field <- set do
      assert field in columns, "#{field} in #{name} is not a column of sections"
    end
  end

  test "the generic writer accepts only open and system-derived fields" do
    assert SectionFields.check(
             %{"previous_next_index" => %{}, amount: nil},
             SectionFields.generic()
           ) ==
             :ok

    for field <- SectionFields.audited() ++ SectionFields.lms_supplied() do
      assert SectionFields.check(%{field => nil}, SectionFields.generic()) == {:error, :protected}

      assert SectionFields.check(%{Atom.to_string(field) => nil}, SectionFields.generic()) ==
               {:error, :protected}
    end
  end

  test "take keeps only the allowed keys, given as atoms or strings" do
    assert SectionFields.take(%{"title" => "T", :agenda => true, "context_id" => "c"}, [
             :title,
             :agenda
           ]) == %{"title" => "T", :agenda => true}
  end
end
