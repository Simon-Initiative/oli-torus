defmodule OliWeb.LayoutViewTest do
  use OliWeb.ConnCase, async: true

  import Oli.Factory

  alias OliWeb.AuthoringView

  describe "authoring view" do
    test "renders author info" do
      author = insert(:author)

      assert AuthoringView.author_role_text(author) == "Author"
      assert AuthoringView.author_role_color(author) == "author-color"
      refute AuthoringView.author_account_linked?(author)
    end

    test "renders admin info" do
      author = insert(:author, system_role_id: Oli.Accounts.SystemRole.role_id().admin)

      assert AuthoringView.author_role_text(author) == "Admin"
      assert AuthoringView.author_role_color(author) == "admin-color"
      refute AuthoringView.author_account_linked?(author)
    end

    test "renders account linked info" do
      author = insert(:author)
      user_associated = insert(:user, author: author)

      assert AuthoringView.author_account_linked?(author)
      assert AuthoringView.author_user_associated_email(author) == user_associated.email
    end
  end
end
