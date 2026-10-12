defmodule OliWeb.ManualGrading.BrowseParamsTest do
  use ExUnit.Case, async: true

  alias Oli.Delivery.Attempts.ManualGrading.BrowseOptions
  alias OliWeb.ManualGrading.BrowseParams

  describe "id_list/3" do
    test "accepts a JSON list of integers or decimal strings, deduplicated and sorted" do
      assert BrowseParams.id_list(%{"selected_user_ids" => "[5]"}, "selected_user_ids") == [5]
      assert BrowseParams.id_list(%{"selected_user_ids" => "[\"5\"]"}, "selected_user_ids") == [5]
      assert BrowseParams.id_list(%{"selected_user_ids" => "[5,5]"}, "selected_user_ids") == [5]

      assert BrowseParams.id_list(%{"selected_user_ids" => "[7,3,7]"}, "selected_user_ids") == [
               3,
               7
             ]
    end

    test "discards values that are not a positive bigint and keeps the valid ones" do
      for value <- ["[-1]", "[0]", "[9223372036854775808]", "[\"5a\"]", "[1.5]", "[true]"] do
        assert BrowseParams.id_list(%{"selected_user_ids" => value}, "selected_user_ids") == [],
               value
      end

      assert BrowseParams.id_list(%{"selected_user_ids" => "[5,-1,\"x\"]"}, "selected_user_ids") ==
               [5]

      assert BrowseParams.id_list(
               %{"selected_user_ids" => "[9223372036854775807]"},
               "selected_user_ids"
             ) == [9_223_372_036_854_775_807]
    end

    test "any shape that is not a flat JSON list of ids is an empty filter, never a crash" do
      for value <- ["[5junk", "{\"a\":1}", "[[1]]", %{"a" => "1"}, ["5"], 5, "", nil] do
        assert BrowseParams.id_list(%{"selected_user_ids" => value}, "selected_user_ids") == [],
               inspect(value)
      end

      assert BrowseParams.id_list(%{}, "selected_user_ids") == []
    end

    test "a legacy scalar param is read as a one-element list only when the list param is absent" do
      assert BrowseParams.id_list(%{"user_id" => "5"}, "selected_user_ids", "user_id") == [5]
      assert BrowseParams.id_list(%{"user_id" => "5junk"}, "selected_user_ids", "user_id") == []

      assert BrowseParams.id_list(%{"user_id" => %{"a" => 1}}, "selected_user_ids", "user_id") ==
               []

      assert BrowseParams.id_list(
               %{"user_id" => "5", "selected_user_ids" => "[9]"},
               "selected_user_ids",
               "user_id"
             ) == [9]
    end
  end

  describe "scalar params" do
    test "text_search is a string or empty" do
      assert BrowseParams.text_search(%{"text_search" => " ana "}) == " ana "
      assert BrowseParams.text_search(%{"text_search" => %{"a" => "1"}}) == ""
      assert BrowseParams.text_search(%{"text_search" => ["a"]}) == ""
      assert BrowseParams.text_search(%{}) == ""
    end

    test "graded is true, false or nil" do
      assert BrowseParams.graded(%{"graded" => "true"}) == true
      assert BrowseParams.graded(%{"graded" => "false"}) == false
      assert BrowseParams.graded(%{"graded" => "maybe"}) == nil
      assert BrowseParams.graded(%{"graded" => %{}}) == nil
      assert BrowseParams.graded(%{}) == nil
    end

    test "offset is a non-negative integer, 0 otherwise" do
      assert BrowseParams.offset(%{"offset" => "30"}) == 30
      assert BrowseParams.offset(%{"offset" => "-3"}) == 0
      assert BrowseParams.offset(%{"offset" => "3junk"}) == 0
      assert BrowseParams.offset(%{"offset" => %{}}) == 0
      assert BrowseParams.offset(%{}) == 0
    end

    test "attempt_id is a positive bigint or :error" do
      assert BrowseParams.attempt_id("42") == {:ok, 42}
      assert BrowseParams.attempt_id("9223372036854775807") == {:ok, 9_223_372_036_854_775_807}

      for value <- ["0", "-1", "9223372036854775808", "42junk", "", nil, %{"a" => "1"}, ["42"]] do
        assert BrowseParams.attempt_id(value) == :error, inspect(value)
      end
    end
  end

  describe "decimal strings are whole strings of digits" do
    test "a trailing newline is not a digit: every reader treats the value as invalid, never raising" do
      assert BrowseParams.id_list(%{"user_id" => "5\n"}, "selected_user_ids", "user_id") == []

      assert BrowseParams.id_list(%{"selected_user_ids" => ~s|["5\\n"]|}, "selected_user_ids") ==
               []

      assert BrowseParams.offset(%{"offset" => "5\n"}) == 0
      assert BrowseParams.attempt_id("5\n") == :error
    end

    test "a decimal with more digits than any bigint is past the range for every reader, never raising" do
      # String.to_integer/1 raises SystemLimitError from about 1.3 million digits.
      digits = String.duplicate("9", 1_300_000)

      assert BrowseParams.offset(%{"offset" => digits}) == 9_223_372_036_854_775_807
      assert BrowseParams.id_list(%{"user_id" => digits}, "selected_user_ids", "user_id") == []

      assert BrowseParams.id_list(
               %{"selected_user_ids" => ~s|["#{digits}"]|},
               "selected_user_ids"
             ) ==
               []

      assert BrowseParams.attempt_id(digits) == :error
    end

    test "leading zeros do not make a decimal longer than its value" do
      padded = String.duplicate("0", 30) <> "5"

      assert BrowseParams.offset(%{"offset" => padded}) == 5
      assert BrowseParams.id_list(%{"user_id" => padded}, "selected_user_ids", "user_id") == [5]
      assert BrowseParams.attempt_id(padded) == {:ok, 5}
    end
  end

  describe "offset/1 bounds" do
    test "an offset beyond what PostgreSQL can encode becomes the largest bigint, past every page" do
      max = 9_223_372_036_854_775_807

      assert BrowseParams.offset(%{"offset" => "9223372036854775808"}) == max
      assert BrowseParams.offset(%{"offset" => 9_223_372_036_854_775_808}) == max
      assert BrowseParams.offset(%{"offset" => Integer.to_string(max)}) == max
    end
  end

  describe "sorting/1" do
    test "accepts the table's sort fields and directions, defaulting to date submitted descending" do
      assert BrowseParams.sorting(%{"sort_by" => "user", "sort_order" => "asc"}) ==
               %Oli.Repo.Sorting{field: :user, direction: :asc}

      assert BrowseParams.sorting(%{"sort_by" => "page_title", "sort_order" => "desc"}) ==
               %Oli.Repo.Sorting{field: :page_title, direction: :desc}

      assert BrowseParams.sorting(%{}) ==
               %Oli.Repo.Sorting{field: :date_submitted, direction: :desc}
    end

    test "any field or direction outside the allowlist falls back to the default, never raising" do
      assert BrowseParams.sorting(%{"sort_by" => "password_hash", "sort_order" => "asc"}) ==
               %Oli.Repo.Sorting{field: :date_submitted, direction: :asc}

      assert BrowseParams.sorting(%{"sort_by" => "user", "sort_order" => "sideways"}) ==
               %Oli.Repo.Sorting{field: :user, direction: :desc}

      assert BrowseParams.sorting(%{"sort_by" => %{"a" => 1}, "sort_order" => ["asc"]}) ==
               %Oli.Repo.Sorting{field: :date_submitted, direction: :desc}
    end
  end

  describe "browse_options/1" do
    test "builds the BrowseOptions from the URL params with every field normalized" do
      params = %{
        "text_search" => "ana",
        "selected_user_ids" => "[2,1]",
        "activity_id" => "7",
        "selected_page_ids" => "[[1]]",
        "graded" => "false"
      }

      assert BrowseParams.browse_options(params) == %BrowseOptions{
               text_search: "ana",
               user_ids: [1, 2],
               activity_ids: [7],
               page_ids: [],
               graded: false
             }
    end

    test "an empty map is the unfiltered options" do
      assert BrowseParams.browse_options(%{}) == %BrowseOptions{
               text_search: "",
               user_ids: [],
               activity_ids: [],
               page_ids: [],
               graded: nil
             }
    end
  end
end
