defmodule OliWeb.Common.UtilsTest do
  use ExUnit.Case, async: true

  alias Oli.Accounts.User
  alias OliWeb.Common.SessionContext
  alias OliWeb.Common.Utils

  import ExUnit.CaptureLog

  doctest Utils, import: true

  describe "name_and_email/1" do
    test "returns name with email when user has email" do
      user = %User{
        given_name: "John",
        family_name: "Doe",
        email: "john.doe@example.com",
        name: nil,
        guest: false
      }

      result = Utils.name_and_email(user)

      assert result == "Doe, John (john.doe@example.com)"
    end

    test "returns just name when email is nil" do
      user = %User{
        given_name: "Jane",
        family_name: "Smith",
        email: nil,
        name: nil,
        guest: false
      }

      result = Utils.name_and_email(user)

      assert result == "Smith, Jane"
    end

    test "returns just name when email is empty string" do
      user = %User{
        given_name: "Bob",
        family_name: "Johnson",
        email: "",
        name: nil,
        guest: false
      }

      result = Utils.name_and_email(user)

      assert result == "Johnson, Bob"
    end

    test "returns just Guest Student when guest user has no email" do
      user = %User{
        guest: true,
        email: nil,
        name: nil,
        given_name: nil,
        family_name: nil
      }

      result = Utils.name_and_email(user)

      assert result == "Guest Student"
    end

    test "handles user with only name field" do
      user = %User{
        name: "Test User",
        given_name: nil,
        family_name: nil,
        email: "test@example.com",
        guest: false
      }

      result = Utils.name_and_email(user)

      assert result == "Test User (test@example.com)"
    end

    test "handles user with no name fields" do
      user = %User{
        name: nil,
        given_name: nil,
        family_name: nil,
        email: "unknown@example.com",
        guest: false
      }

      result = Utils.name_and_email(user)

      assert result == "Unknown (unknown@example.com)"
    end
  end

  describe "extract_feedback_text/1" do
    test "extracts the feedback text from an attempt and logs an error if it can not be parsed" do
      activity_attempts = [
        %{
          part_attempts: [
            %{
              feedback: %{
                "content" => [
                  %{
                    "children" => [%{"text" => "First Feedback"}],
                    "id" => "7brHHbLfce3qYbdU8rkk23",
                    "type" => "p"
                  }
                ]
              }
            },
            %{
              feedback: %{
                "content" => [
                  %{
                    "children" => [%{"text" => "Second Feedback"}],
                    "id" => "7brHHbLfce3qYbdU8rkk23",
                    "type" => "p"
                  }
                ]
              }
            },
            %{
              feedback: %{
                "content" => %{
                  "model" => [
                    %{
                      "children" => [%{"text" => "Third Feedback"}],
                      "id" => "7brHHbLfce3qYbdU8rkk23",
                      "type" => "p"
                    }
                  ]
                }
              }
            },
            %{
              feedback: %{
                "content" => %{
                  "some_other_case" => [
                    %{
                      "children" => [
                        %{
                          "text" =>
                            "This feedback does not match any known case, so a Log error should be triggered"
                        }
                      ],
                      "id" => "7brHHbLfce3qYbdU8rkk23",
                      "type" => "p"
                    }
                  ]
                }
              }
            }
          ]
        }
      ]

      {result, log} =
        with_log(fn ->
          Utils.extract_feedback_text(activity_attempts)
        end)

      assert result == ["First Feedback", "Second Feedback", "Third Feedback"]

      assert log =~
               "[error] Could not parse feedback text from {\"some_other_case\", [%{\"children\" => [%{\"text\" => \"This feedback does not match any known case, so a Log error should be triggered\"}], \"id\" => \"7brHHbLfce3qYbdU8rkk23\", \"type\" => \"p\"}]}"
    end
  end
end
