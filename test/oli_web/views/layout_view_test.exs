defmodule OliWeb.LayoutViewTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory

  alias OliWeb.AuthoringView
  alias OliWeb.LayoutView

  describe "authoring view" do
    test "renders author info" do
      author = insert(:author)

      assert AuthoringView.author_role_text(author) == "Author"
      assert AuthoringView.author_role_color(author) == "author-color"
      refute AuthoringView.author_linked_account(author)
    end

    test "renders admin info" do
      author = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().system_admin)

      assert AuthoringView.author_role_text(author) == "Admin"
      assert AuthoringView.author_role_color(author) == "admin-color"
      refute AuthoringView.author_linked_account(author)
    end

    test "renders account linked info" do
      author = insert(:author)
      user_associated = insert(:user, author: author)

      user = AuthoringView.author_linked_account(author)
      assert user
      assert user.id == user_associated.id
    end

    test "is_only_url?/1" do
      assert LayoutView.is_only_url?("http://foo")
      assert LayoutView.is_only_url?("https://foo")
      assert LayoutView.is_only_url?(" https://foo ")
      refute LayoutView.is_only_url?("foo")
      refute LayoutView.is_only_url?("foo.com")
      refute LayoutView.is_only_url?("https://foo.com bar")
    end
  end
end
