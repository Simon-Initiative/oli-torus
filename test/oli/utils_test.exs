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
end
