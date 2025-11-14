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

    test "parses delivery field correctly" do
      params_dd = %{"filter_delivery" => "dd"}
      filters_dd = BrowseFilters.parse(params_dd)
      assert filters_dd.delivery == :dd

      params_lti = %{"filter_delivery" => "lti"}
      filters_lti = BrowseFilters.parse(params_lti)
      assert filters_lti.delivery == :lti

      params_invalid = %{"filter_delivery" => "invalid"}
      filters_invalid = BrowseFilters.parse(params_invalid)
      assert filters_invalid.delivery == nil
    end

    test "parses requires_payment field correctly" do
      params_true = %{"filter_requires_payment" => "true"}
      filters_true = BrowseFilters.parse(params_true)
      assert filters_true.requires_payment == true

      params_false = %{"filter_requires_payment" => "false"}
      filters_false = BrowseFilters.parse(params_false)
      assert filters_false.requires_payment == false

      params_invalid = %{"filter_requires_payment" => "invalid"}
      filters_invalid = BrowseFilters.parse(params_invalid)
      assert filters_invalid.requires_payment == nil
    end
  end

  describe "normalize_form_params/1" do
    test "normalizes delivery field" do
      params = %{"delivery" => "dd"}
      normalized = BrowseFilters.normalize_form_params(params)
      assert normalized["filter_delivery"] == "dd"
    end

    test "normalizes requires_payment field" do
      params = %{"requires_payment" => "true"}
      normalized = BrowseFilters.normalize_form_params(params)
      assert normalized["filter_requires_payment"] == "true"
    end

    test "ignores empty values" do
      params = %{"delivery" => "", "requires_payment" => ""}
      normalized = BrowseFilters.normalize_form_params(params)
      refute Map.has_key?(normalized, "filter_delivery")
      refute Map.has_key?(normalized, "filter_requires_payment")
    end
  end

  describe "active_count/1" do
    test "counts delivery filter as active" do
      filters = %BrowseFilters.State{delivery: :dd}
      assert BrowseFilters.active_count(filters) == 1
    end

    test "counts requires_payment filter as active" do
      filters = %BrowseFilters.State{requires_payment: true}
      assert BrowseFilters.active_count(filters) == 1
    end

    test "counts multiple filters including new fields" do
      filters = %BrowseFilters.State{
        delivery: :lti,
        requires_payment: false,
        status: :active
      }

      assert BrowseFilters.active_count(filters) == 3
    end
  end

  describe "to_query_params/1" do
    test "includes delivery in query params" do
      filters = %BrowseFilters.State{delivery: :dd}
      params = BrowseFilters.to_query_params(filters, as: :atoms)
      assert params[:filter_delivery] == "dd"
    end

    test "includes requires_payment in query params" do
      filters = %BrowseFilters.State{requires_payment: true}
      params = BrowseFilters.to_query_params(filters, as: :atoms)
      assert params[:filter_requires_payment] == "true"
    end

    test "omits nil values" do
      filters = %BrowseFilters.State{delivery: nil, requires_payment: nil}
      params = BrowseFilters.to_query_params(filters, as: :atoms)
      refute Map.has_key?(params, :filter_delivery)
      refute Map.has_key?(params, :filter_requires_payment)
    end
  end

  describe "to_course_filters/1" do
    test "converts delivery :dd to filter_type :open" do
      filters = %BrowseFilters.State{delivery: :dd}
      course_filters = BrowseFilters.to_course_filters(filters)
      assert course_filters.delivery == :open
    end

    test "converts delivery :lti to filter_type :lms" do
      filters = %BrowseFilters.State{delivery: :lti}
      course_filters = BrowseFilters.to_course_filters(filters)
      assert course_filters.delivery == :lms
    end

    test "includes requires_payment in course filters" do
      filters = %BrowseFilters.State{requires_payment: true}
      course_filters = BrowseFilters.to_course_filters(filters)
      assert course_filters.requires_payment == true
    end
  end
end
