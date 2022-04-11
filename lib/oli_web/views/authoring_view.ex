defmodule OliWeb.AuthoringView do
  use OliWeb, :view
  use Phoenix.Component

  alias Oli.Accounts
  alias Oli.Accounts.{Author, User}

  def author_role_text(author) do
    if Accounts.is_admin?(author),
      do: "Admin",
      else: "Author"
  end

  def author_role_color(author) do
    if Accounts.is_admin?(author),
      do: "#2ecc71",
      else: "#3498db"
  end

  def author_account_linked?(%Author{} = author),
    do: Accounts.get_user_by(author_id: author.id) != nil

  def author_user_associated_email(author) do
    %User{email: email} = Accounts.get_user_by(author_id: author.id)
    email
  end

  def author_icon(%{current_autor: current_autor} = assigns) do
    case current_autor.picture do
      nil ->
        author_icon(%{})

      picture ->
        ~H"""
        <div class="user-icon">
          <img src={picture} class="rounded-circle" />
        </div>
        """
    end
  end

  def author_icon(assigns) do
    ~H"""
    <div class="user-icon">
      <div class="user-img rounded-circle">
        <span class="material-icons text-secondary">account_circle</span>
      </div>
    </div>
    """
  end
end
