defmodule Oli.EmailTest do
  use ExUnit.Case, async: true

  alias Oli.Email

  describe "base_email/0" do
    test "creates email with from address from config" do
      email = Email.base_email()

      assert email.from == {
               Application.get_env(:oli, :email_from_name),
               Application.get_env(:oli, :email_from_address)
             }
    end

    test "does not set reply_to by default" do
      email = Email.base_email()

      assert email.reply_to == nil
    end

    test "sets Errors-To header when configured" do
      # Store original value
      original = Application.get_env(:oli, :email_errors_to_address)

      # Set test value
      Application.put_env(:oli, :email_errors_to_address, "errors@test.com")

      email = Email.base_email()

      assert email.headers["Errors-To"] == "errors@test.com"

      # Restore original value
      Application.put_env(:oli, :email_errors_to_address, original)
    end

    test "does not set Errors-To header when not configured" do
      # Store original value
      original = Application.get_env(:oli, :email_errors_to_address)

      # Set to nil
      Application.put_env(:oli, :email_errors_to_address, nil)

      email = Email.base_email()

      refute Map.has_key?(email.headers, "Errors-To")

      # Restore original value
      Application.put_env(:oli, :email_errors_to_address, original)
    end

    test "sets Return-Path header when configured" do
      # Store original value
      original = Application.get_env(:oli, :email_return_path_address)

      # Set test value
      Application.put_env(:oli, :email_return_path_address, "return@test.com")

      email = Email.base_email()

      assert email.headers["Return-Path"] == "return@test.com"

      # Restore original value
      Application.put_env(:oli, :email_return_path_address, original)
    end

    test "does not set Return-Path header when not configured" do
      # Store original value
      original = Application.get_env(:oli, :email_return_path_address)

      # Set to nil
      Application.put_env(:oli, :email_return_path_address, nil)

      email = Email.base_email()

      refute Map.has_key?(email.headers, "Return-Path")

      # Restore original value
      Application.put_env(:oli, :email_return_path_address, original)
    end
  end

  describe "create_email/4" do
    test "creates email with recipient, subject, and does not set reply_to" do
      email =
        Email.create_email("recipient@test.com", "Test Subject", :email_confirmation, %{
          url: "http://test.com"
        })

      assert email.to == [{"", "recipient@test.com"}]
      assert email.subject == "Test Subject"
      assert email.reply_to == nil
    end

    test "inherits from address from base_email" do
      email =
        Email.create_email("recipient@test.com", "Test Subject", :email_confirmation, %{
          url: "http://test.com"
        })

      assert email.from == {
               Application.get_env(:oli, :email_from_name),
               Application.get_env(:oli, :email_from_address)
             }
    end
  end

  describe "create_text_email/3" do
    test "creates text-only email with recipient and subject" do
      email = Email.create_text_email("recipient@test.com", "Test Subject", "Test body content")

      assert email.to == [{"", "recipient@test.com"}]
      assert email.subject == "Test Subject"
      assert email.text_body == "Test body content"
      assert email.html_body == nil
    end

    test "does not set reply_to" do
      email = Email.create_text_email("recipient@test.com", "Test Subject", "Test body")

      assert email.reply_to == nil
    end
  end

  describe "help_desk_email/6" do
    test "uses default from address (for SES compatibility) instead of user's email" do
      email =
        Email.help_desk_email(
          "User Name",
          "user@test.com",
          "helpdesk@test.com",
          "Help Request",
          :help_email,
          %{message: "Test message"}
        )

      # FROM should be the configured default, not the user's email
      # (Amazon SES requires verified sender addresses)
      assert email.from == {
               Application.get_env(:oli, :email_from_name),
               Application.get_env(:oli, :email_from_address)
             }
    end

    test "sets reply_to to the user's email" do
      email =
        Email.help_desk_email(
          "User Name",
          "user@test.com",
          "helpdesk@test.com",
          "Help Request",
          :help_email,
          %{message: "Test message"}
        )

      assert email.reply_to == {"User Name", "user@test.com"}
    end

    test "sets to to the help desk email" do
      email =
        Email.help_desk_email(
          "User Name",
          "user@test.com",
          "helpdesk@test.com",
          "Help Request",
          :help_email,
          %{message: "Test message"}
        )

      assert email.to == [{"", "helpdesk@test.com"}]
    end

    test "sets the subject correctly" do
      email =
        Email.help_desk_email(
          "User Name",
          "user@test.com",
          "helpdesk@test.com",
          "Help Request Subject",
          :help_email,
          %{message: "Test message"}
        )

      assert email.subject == "Help Request Subject"
    end
  end
end
