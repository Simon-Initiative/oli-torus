defmodule Oli.UtilsTest do
  use Oli.DataCase

  alias Oli.Utils

  describe "is_url_absolute" do
    test "returns true if url is absolute" do
      assert Utils.is_url_absolute("http://example.com") == true
      assert Utils.is_url_absolute("HTTP://EXAMPLE.COM") == true
      assert Utils.is_url_absolute("https://www.exmaple.com") == true
      assert Utils.is_url_absolute("ftp://example.com/file.txt") == true
      assert Utils.is_url_absolute("ftp://example.com/file.txt") == true
      assert Utils.is_url_absolute("//cdn.example.com/lib.js") == true
      assert Utils.is_url_absolute("/myfolder/test.txt") == false
      assert Utils.is_url_absolute("test") == false
    end
  end

  describe "normalize_whitespace" do
    test "removes whitespace" do
      assert Utils.normalize_whitespace("  test  ") == "test"
      assert Utils.normalize_whitespace("  test test  ") == "test test"
      assert Utils.normalize_whitespace("  test   test  ") == "test test"
    end
  end

  describe "ensure_absolute_url" do
    test "returns an absolute url" do
      assert Utils.ensure_absolute_url("test") == "https://localhost/test"
      assert Utils.ensure_absolute_url("/test") == "https://localhost/test"

      assert Utils.ensure_absolute_url("/keeps/path?and=all&params=true") ==
               "https://localhost/keeps/path?and=all&params=true"

      assert Utils.ensure_absolute_url("http://already-aboslute") == "http://already-aboslute"
      assert Utils.ensure_absolute_url("https://already-aboslute") == "https://already-aboslute"

      assert Utils.ensure_absolute_url(
               "https://already-aboslute:8080/keeps/path?and=all&params=true"
             ) ==
               "https://already-aboslute:8080/keeps/path?and=all&params=true"
    end

    test "returns an empty string when the input url is nil" do
      assert Utils.ensure_absolute_url(nil) == ""
    end
  end

  describe "find_and_linkify_urls_in_string/1" do
    test "linkifies url when present in string" do
      url = "http://www.example.com"
      test_string = "Please go to #{url}"

      assert Utils.find_and_linkify_urls_in_string(test_string) =~
               "<a href=\"#{url}\" target=\"_blank\">#{url}</a>"
    end

    test "linkifies url and makes it absolute when present in string" do
      url = "www.example.com"
      test_string = "Please go to #{url}"

      assert Utils.find_and_linkify_urls_in_string(test_string) =~
               "<a href=\"//#{url}\" target=\"_blank\">#{url}</a>"
    end

    test "returns the same string when there is no url" do
      test_string = "test string"

      assert Utils.find_and_linkify_urls_in_string(test_string) == test_string
    end
  end

  describe "stringify_atom/1" do
    test "returns the string representation of an atom without underscores" do
      assert Utils.stringify_atom(:this_is_a_test) == "this is a test"
    end
  end

  describe "validate_email/1" do
    test "validates emails with internationalized domains (IDN)" do
      assert Utils.validate_email("user@exämple.com")
      assert Utils.validate_email("user@münchen.de")
      assert Utils.validate_email("user@中国.cn")
    end

    test "rejects invalid emails" do
      # Invalid local part
      refute Utils.validate_email("user..name@example.com")
      refute Utils.validate_email(".user@example.com")
      refute Utils.validate_email("user.@example.com")
      refute Utils.validate_email("user name@example.com")
      refute Utils.validate_email("user\\@name@example.com")

      # Invalid domain part
      refute Utils.validate_email("user@-example.com")
      refute Utils.validate_email("user@example-.com")
      refute Utils.validate_email("user@.example.com")
      refute Utils.validate_email("user@example..com")
      refute Utils.validate_email("user@example.com-")
      # Single character TLD
      refute Utils.validate_email("user@example.c")
      # Missing TLD
      refute Utils.validate_email("user@example")

      # Length violations
      # Local part > 64 chars
      refute Utils.validate_email(String.duplicate("a", 65) <> "@example.com")
      # Domain label > 63 chars
      refute Utils.validate_email("user@" <> String.duplicate("a", 64) <> ".com")
      # Domain > 255 chars
      refute Utils.validate_email("user@" <> String.duplicate("a.a", 128))
      # Total > 254 chars
      refute Utils.validate_email(String.duplicate("a", 255) <> "@example.com")

      # Invalid input types
      refute Utils.validate_email(nil)
      refute Utils.validate_email(123)
      refute Utils.validate_email(%{})
    end

    test "accepts valid emails" do
      # Basic valid emails
      assert Utils.validate_email("user@example.com")
      assert Utils.validate_email("user.name@example.com")
      assert Utils.validate_email("user+tag@example.com")
      assert Utils.validate_email("user123@example.com")
      assert Utils.validate_email("user@subdomain.example.com")

      # Valid special characters in local part
      assert Utils.validate_email("!#$%&'*+-/=?^_`{|}~@example.com")
      assert Utils.validate_email("user.!#$%&'*+-/=?^_`{|}~@example.com")
      assert Utils.validate_email("\"Fred Bloggs\"@example.com")
      assert Utils.validate_email("\"Abc@def\"@example.com")

      # Valid domain variations
      assert Utils.validate_email("user@example.co.uk")
      assert Utils.validate_email("user@example.museum")
      assert Utils.validate_email("user@123.example.com")
      assert Utils.validate_email("user@sub-domain.example.com")

      # Edge cases that should be valid
      # Minimal length but valid
      assert Utils.validate_email("a@b.cd")
      # Max local part
      assert Utils.validate_email(String.duplicate("a", 64) <> "@example.com")
      # Max label length
      assert Utils.validate_email("user@" <> String.duplicate("a", 63) <> ".com")
    end
  end
end
