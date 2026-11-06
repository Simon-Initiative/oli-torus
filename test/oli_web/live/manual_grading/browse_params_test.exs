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

  describe "the limit of 200 ids per list" do
    defp ids_json(count), do: Jason.encode!(Enum.to_list(1..count))

    test "a list of up to 200 ids applies; a longer one is an empty filter and is reported" do
      at_limit = %{"selected_user_ids" => ids_json(200)}
      past_limit = %{"selected_user_ids" => ids_json(201)}

      assert BrowseParams.id_list(at_limit, "selected_user_ids") == Enum.to_list(1..200)
      assert BrowseParams.over_limit(at_limit) == []

      assert BrowseParams.id_list(past_limit, "selected_user_ids") == []
      assert BrowseParams.browse_options(past_limit).user_ids == []
      assert BrowseParams.over_limit(past_limit) == [:user_ids]
    end

    test "the limit counts distinct valid ids, not list elements" do
      repeated = %{"selected_page_ids" => Jason.encode!(Enum.to_list(1..200) ++ [1, 2, -5, "x"])}

      assert length(BrowseParams.id_list(repeated, "selected_page_ids")) == 200
      assert BrowseParams.over_limit(repeated) == []
    end

    test "every list is checked on its own" do
      params = %{
        "selected_user_ids" => ids_json(3),
        "selected_activity_ids" => ids_json(201),
        "selected_page_ids" => ids_json(250)
      }

      assert BrowseParams.over_limit(params) == [:activity_ids, :page_ids]
      assert BrowseParams.browse_options(params).user_ids == [1, 2, 3]
      assert BrowseParams.browse_options(params).activity_ids == []
      assert BrowseParams.browse_options(params).page_ids == []
    end

    test "an old filter key is read only as a single value; a list in it is no filter" do
      assert BrowseParams.browse_options(%{"user_id" => "5"}).user_ids == [5]

      for {legacy, option} <- [user_id: :user_ids, activity_id: :activity_ids, page_id: :page_ids] do
        two = Plug.Conn.Query.decode("#{legacy}[]=1&#{legacy}[]=2")
        many = Plug.Conn.Query.decode(Enum.map_join(1..201, "&", &"#{legacy}[]=#{&1}"))

        assert Map.fetch!(BrowseParams.browse_options(two), option) == []
        assert Map.fetch!(BrowseParams.browse_options(many), option) == []
      end

      assert BrowseParams.table_params(Plug.Conn.Query.decode("user_id[]=1&user_id[]=2")) ==
               %{"selected_user_ids" => "[]"}
    end

    test "the byte budget admits 200 of the longest ids; a longer text, valid or not, is past the limit" do
      longest = ~s|"#{9_223_372_036_854_775_807}", |
      at_limit = "[" <> String.duplicate(longest, 199) <> ~s|"9223372036854775806"]|

      assert length(BrowseParams.id_list(%{"selected_user_ids" => at_limit}, "selected_user_ids")) ==
               2

      not_json = "[" <> String.duplicate("1, ", 2_000)

      assert BrowseParams.over_limit(%{"selected_user_ids" => not_json}) == [:user_ids]

      assert BrowseParams.over_limit(%{
               "selected_user_ids" => "[" <> String.duplicate("1, ", 100)
             }) == []
    end
  end

  describe "purposes/1" do
    test "reads graded as the purposes chosen: one value, both as a JSON list, or none" do
      assert BrowseParams.purposes(%{"graded" => "true"}) == [true]
      assert BrowseParams.purposes(%{"graded" => "false"}) == [false]
      assert BrowseParams.purposes(%{"graded" => "[true]"}) == [true]
      assert BrowseParams.purposes(%{"graded" => "[true,false]"}) == [false, true]
      assert BrowseParams.purposes(%{"graded" => "[false,true,true]"}) == [false, true]

      for value <- ["", "[]", "yes", "[1]", "[[true]]", %{"a" => "b"}, nil] do
        assert BrowseParams.purposes(%{"graded" => value}) == [], inspect(value)
      end
    end

    test "graded filters by a single purpose; both purposes, like none, filter nothing" do
      assert BrowseParams.graded(%{"graded" => "[false]"}) == false
      assert BrowseParams.graded(%{"graded" => "[true,false]"}) == nil
      assert BrowseParams.browse_options(%{"graded" => "[false,true]"}).graded == nil
    end

    test "a graded value longer than both purposes need is no filter" do
      many = "[" <> Enum.map_join(1..100, ",", fn _ -> "true" end) <> "]"

      assert BrowseParams.purposes(%{"graded" => "[false, true]"}) == [false, true]
      assert BrowseParams.purposes(%{"graded" => many}) == []
      assert BrowseParams.graded(%{"graded" => many}) == nil
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
