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

      assert Utils.ensure_absolute_url("https://already-aboslute:8080/keeps/path?and=all&params=true") ==
               "https://already-aboslute:8080/keeps/path?and=all&params=true"
    end
  end
end
