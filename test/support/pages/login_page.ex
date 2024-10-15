defmodule LoginPage do
  use Hound.Helpers
  alias OliWeb.Router.Helpers, as: Routes

  def open do
    navigate_to("#{Application.get_env(:hound, :torus_base_url)}/")
  end

  def close_cookie_prompt do
    # Make sure the dialog & button are there
    # Then click the accept button
    with {:ok, _} <- search_element(:xpath, "//*[text() = 'We use cookies']"),
         {:ok, button} <- search_element(:xpath, "//*[text() = 'Accept']") do
      click(button)
    end
  end

  def go_to_author_login do
    click({:link_text, "Authoring Sign In"})
  end

  def go_to_educator_login do
    # TODO - It would be better for these to have explicit id or aria-label attributes instead of relying on the implemention-detail of the url they go to
    click({:xpath, "//*[@href='#{~p"/users/log_in"}']"})
  end

  def login("", _), do: IO.puts("Username / Password not specified")
  def login(_, ""), do: IO.puts("Username / Password not specified")

  def login(username, password) do
    element = find_element(:id, "user_email")
    fill_field(element, username)
    element = find_element(:id, "user_password")
    fill_field(element, password)
    submit_element(element)
  end
end
