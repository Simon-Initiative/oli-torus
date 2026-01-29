defmodule Oli.Analytics.ClickhouseQueryValidatorTest do
  use ExUnit.Case, async: true

  alias Oli.Analytics.ClickhouseQueryValidator

  describe "validate_custom_query/3" do
    test "accepts a scoped select query" do
      query = "SELECT count() FROM raw_events WHERE section_id = 42"

      assert :ok ==
               ClickhouseQueryValidator.validate_custom_query(query, :section_id, 42)
    end

    test "accepts a scoped select query using IN" do
      query = "SELECT * FROM raw_events WHERE section_id IN (41, 42, 43)"

      assert :ok ==
               ClickhouseQueryValidator.validate_custom_query(query, :section_id, 42)
    end

    test "accepts a scoped select query with CTE filter" do
      query = """
      WITH scoped AS (
        SELECT * FROM raw_events WHERE section_id = 42
      )
      SELECT count() FROM scoped
      """

      assert :ok ==
               ClickhouseQueryValidator.validate_custom_query(query, :section_id, 42)
    end

    test "rejects non-select statements" do
      query = "INSERT INTO raw_events VALUES (1)"

      assert {:error, _} =
               ClickhouseQueryValidator.validate_custom_query(query, :section_id, 42)
    end

    test "rejects multiple statements" do
      query = "SELECT 1; SELECT 2"

      assert {:error, _} =
               ClickhouseQueryValidator.validate_custom_query(query, :section_id, 42)
    end

    test "rejects missing scope filter" do
      query = "SELECT count() FROM raw_events"

      assert {:error, _} =
               ClickhouseQueryValidator.validate_custom_query(query, :section_id, 42)
    end

    test "rejects incorrect scope filter" do
      query = "SELECT count() FROM raw_events WHERE section_id = 41"

      assert {:error, _} =
               ClickhouseQueryValidator.validate_custom_query(query, :section_id, 42)
    end

    test "rejects other scope field in section validation" do
      query = "SELECT count() FROM raw_events WHERE project_id = 10"

      assert {:error, _} =
               ClickhouseQueryValidator.validate_custom_query(query, :section_id, 42)
    end
  end
end
