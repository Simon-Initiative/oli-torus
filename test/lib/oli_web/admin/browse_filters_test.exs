defmodule OliWeb.Admin.BrowseFiltersTest do
  use ExUnit.Case, async: true

  alias OliWeb.Admin.BrowseFilters

  describe "parse/1" do
    test "falls back to defaults for unsupported atom values" do
      params = %{
        "filter_date_field" => "published",
        "filter_visibility" => "public",
        "filter_status" => "archived"
      }

      filters = BrowseFilters.parse(params)

      assert filters.date_field == :inserted_at
      assert filters.visibility == nil
      assert filters.status == nil
    end

    test "accepts supported atoms" do
      params = %{
        "filter_date_field" => "inserted_at",
        "filter_visibility" => "authors",
        "filter_status" => "deleted"
      }

      filters = BrowseFilters.parse(params)

      assert filters.date_field == :inserted_at
      assert filters.visibility == :authors
      assert filters.status == :deleted
    end
  end
end
