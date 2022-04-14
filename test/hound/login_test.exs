defmodule Hound.LoginTest do
  use Oli.HoundCase

  setup [:account_seed]

  @doc """
  This test will:
    1. Attempt to log into an unconfirmed author account
    2. Verify the correct alert is displayed
    3. Switch the account to verified
    4. Attempt to log in and verify it's successful
  """
  hound_test "Author Login", %{user: user, password: password} do
    set_window_size(
      current_window_handle(),
      1000,
      800
    )

    LoginPage.open()
    LoginPage.close_cookie_prompt()
    LoginPage.go_to_author_login()
    LoginPage.login(user.email, password)

    message =
      "You'll need to confirm your e-mail before you can sign in. An e-mail confirmation link has been sent to you."

    alert = find_element(:css, ".alert-info")
    assert visible_text(alert) =~ message

    Oli.Accounts.insert_or_update_author(%{
      email: user.email,
      email_confirmed_at: Timex.now()
    })

    LoginPage.login(user.email, password)

    header = find_element(:css, ".workspace-header h3")
    assert visible_text(header) =~ "Projects"

    assert {:ok, _} = search_element(:id, "button-new-project")
  end

  def account_seed(_) do
    author_seed = Oli.Seeder.create_author_account()

    {:ok, author_seed}
  end
end
