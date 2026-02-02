defmodule Oli.Mailer.SendEmailWorkerTest do
  use ExUnit.Case, async: true

  alias Oli.Mailer.SendEmailWorker

  describe "serialize_email/1 and deserialize_email/1" do
    test "preserves to, from, subject, html_body, and text_body" do
      original_email =
        Swoosh.Email.new()
        |> Swoosh.Email.to({"John Doe", "john@test.com"})
        |> Swoosh.Email.from({"Sender", "sender@test.com"})
        |> Swoosh.Email.subject("Test Subject")
        |> Swoosh.Email.html_body("<p>HTML content</p>")
        |> Swoosh.Email.text_body("Text content")

      serialized = SendEmailWorker.serialize_email(original_email)
      deserialized = SendEmailWorker.deserialize_email(serialized)

      assert deserialized.to == [{"John Doe", "john@test.com"}]
      assert deserialized.from == {"Sender", "sender@test.com"}
      assert deserialized.subject == "Test Subject"
      assert deserialized.html_body == "<p>HTML content</p>"
      assert deserialized.text_body == "Text content"
    end

    test "preserves reply_to as tuple {name, email}" do
      original_email =
        Swoosh.Email.new()
        |> Swoosh.Email.to("recipient@test.com")
        |> Swoosh.Email.from({"Sender", "sender@test.com"})
        |> Swoosh.Email.subject("Test")
        |> Swoosh.Email.reply_to({"Reply Name", "reply@test.com"})

      serialized = SendEmailWorker.serialize_email(original_email)
      deserialized = SendEmailWorker.deserialize_email(serialized)

      assert deserialized.reply_to == {"Reply Name", "reply@test.com"}
    end

    test "preserves reply_to as plain email string" do
      original_email =
        Swoosh.Email.new()
        |> Swoosh.Email.to("recipient@test.com")
        |> Swoosh.Email.from({"Sender", "sender@test.com"})
        |> Swoosh.Email.subject("Test")
        |> Swoosh.Email.reply_to("reply@test.com")

      serialized = SendEmailWorker.serialize_email(original_email)
      deserialized = SendEmailWorker.deserialize_email(serialized)

      assert deserialized.reply_to == {"", "reply@test.com"}
    end

    test "handles nil reply_to" do
      original_email =
        Swoosh.Email.new()
        |> Swoosh.Email.to("recipient@test.com")
        |> Swoosh.Email.from({"Sender", "sender@test.com"})
        |> Swoosh.Email.subject("Test")

      serialized = SendEmailWorker.serialize_email(original_email)
      deserialized = SendEmailWorker.deserialize_email(serialized)

      assert deserialized.reply_to == nil
    end

    test "preserves custom headers (Errors-To, Return-Path)" do
      original_email =
        Swoosh.Email.new()
        |> Swoosh.Email.to("recipient@test.com")
        |> Swoosh.Email.from({"Sender", "sender@test.com"})
        |> Swoosh.Email.subject("Test")
        |> Swoosh.Email.header("Errors-To", "errors@test.com")
        |> Swoosh.Email.header("Return-Path", "return@test.com")

      serialized = SendEmailWorker.serialize_email(original_email)
      deserialized = SendEmailWorker.deserialize_email(serialized)

      assert deserialized.headers["Errors-To"] == "errors@test.com"
      assert deserialized.headers["Return-Path"] == "return@test.com"
    end

    test "handles empty headers" do
      original_email =
        Swoosh.Email.new()
        |> Swoosh.Email.to("recipient@test.com")
        |> Swoosh.Email.from({"Sender", "sender@test.com"})
        |> Swoosh.Email.subject("Test")

      serialized = SendEmailWorker.serialize_email(original_email)
      deserialized = SendEmailWorker.deserialize_email(serialized)

      assert deserialized.headers == %{}
    end

    test "preserves multiple recipients" do
      original_email =
        Swoosh.Email.new()
        |> Swoosh.Email.to([{"John", "john@test.com"}, {"Jane", "jane@test.com"}])
        |> Swoosh.Email.from({"Sender", "sender@test.com"})
        |> Swoosh.Email.subject("Test")

      serialized = SendEmailWorker.serialize_email(original_email)
      deserialized = SendEmailWorker.deserialize_email(serialized)

      assert deserialized.to == [{"John", "john@test.com"}, {"Jane", "jane@test.com"}]
    end

    test "handles backwards compatibility - deserializes email without reply_to or headers fields" do
      # Simulate an email serialized before the fix (without reply_to and headers)
      legacy_serialized = %{
        "to" => [%{"name" => "John", "email" => "john@test.com"}],
        "from" => %{"name" => "Sender", "email" => "sender@test.com"},
        "subject" => "Test Subject",
        "html_body" => "<p>Content</p>",
        "text_body" => "Content"
      }

      deserialized = SendEmailWorker.deserialize_email(legacy_serialized)

      assert deserialized.to == [{"John", "john@test.com"}]
      assert deserialized.from == {"Sender", "sender@test.com"}
      assert deserialized.subject == "Test Subject"
      assert deserialized.reply_to == nil
      assert deserialized.headers == %{}
    end
  end

  describe "serialize_email/1" do
    test "serializes to JSON-compatible format" do
      original_email =
        Swoosh.Email.new()
        |> Swoosh.Email.to({"John", "john@test.com"})
        |> Swoosh.Email.from({"Sender", "sender@test.com"})
        |> Swoosh.Email.subject("Test")
        |> Swoosh.Email.reply_to("reply@test.com")
        |> Swoosh.Email.header("Errors-To", "errors@test.com")

      serialized = SendEmailWorker.serialize_email(original_email)

      # Verify it can be encoded to JSON (required for Oban job args)
      assert {:ok, _json} = Jason.encode(serialized)
    end
  end
end
