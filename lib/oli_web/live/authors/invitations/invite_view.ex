defmodule OliWeb.Authors.Invitations.InviteView do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Accounts.AuthorToken

  import OliWeb.Backgrounds

  def mount(%{"token" => token}, session, socket) do
    case Accounts.get_author_token_by_author_invitation_token(token) do
      nil ->
        {:ok, assign(socket, author: nil)}

      %AuthorToken{author: author} ->
        current_author =
          session["author_token"] &&
            Accounts.get_author_by_session_token(session["author_token"])

        case {new_invited_author?(author),
              current_author_is_the_invited_one?(current_author, author)} do
          {true, _} ->
            # the new author must complete registration
            changeset = Accounts.change_author_registration(author)

            {:ok,
             assign(socket,
               author: author,
               current_author: current_author,
               step: "new_author_account_creation",
               trigger_submit: false,
               check_errors: false,
               recaptcha_error: false
             )
             |> assign_form(changeset)}

          {false, true} ->
            # the invited author already exists and matches the current author
            {:ok, redirect(socket, to: ~p"/workspaces/course_author/")}

          {false, false} ->
            # the invited author already exists but is not the current author (if any)
            # password must be provided to log in

            form = to_form(%{"email" => author.email}, as: "author")

            {:ok,
             assign(socket,
               author: author,
               current_author: current_author,
               step: "existing_author_login",
               form: form,
               trigger_submit: false
             )}
        end
    end
  end

  def render(%{author: nil} = assigns) do
    ~H"""
    <.invite_container>
      <h3 class="text-white">This invitation has expired or does not exist.</h3>
    </.invite_container>
    """
  end

  def render(%{step: "new_author_account_creation"} = assigns) do
    ~H"""
    <.invite_container>
      <h1 class="text-white">Invitation to create an Authoring Account</h1>

      <div class="w-full flex items-center justify-center dark">
        <Components.Auth.registration_form
          title="Create Account"
          form={@form}
          action={~p"/authors/accept_invitation?email=#{@author.email}"}
          trigger_submit={@trigger_submit}
          recaptcha_error={@recaptcha_error}
          check_errors={@check_errors}
          disabled_inputs={[:email]}
        />
      </div>
    </.invite_container>
    """
  end

  def render(%{step: "existing_author_login"} = assigns) do
    ~H"""
    <.invite_container>
      <h1 class="text-white">Invitation to create an Authoring Account</h1>

      <div class="w-full flex items-center justify-center dark">
        <Components.Auth.login_form
          title="Sign In"
          form={@form}
          action={~p"/authors/accept_invitation?email=#{@author.email}"}
          reset_password_link={~p"/authors/reset_password"}
          trigger_submit={@trigger_submit}
          submit_event="log_in_existing_author"
          disabled_inputs={[:email]}
        />
      </div>

      <div
        :if={!is_nil(@current_author) && @current_author.id != @author.id}
        class="text-xs text-bold"
      >
        <p role="account warning" class="text-white">
          You are currently logged in as <strong><%= @current_author.email %></strong>.<br />
          You will be automatically logged in as <strong>{@author.email}</strong>
          after you sign in.
        </p>
      </div>
    </.invite_container>
    """
  end

  slot :inner_block

  def invite_container(assigns) do
    ~H"""
    <div class="relative h-[calc(100vh-180px)] w-full flex justify-center items-center">
      <div class="absolute h-[calc(100vh-180px)] w-full top-0 left-0">
        <.author_invitation />
      </div>
      <div class="flex flex-col justify-center items-center gap-y-10 w-full relative z-50 overflow-y-scroll lg:overflow-y-auto h-[calc(100vh-270px)] md:h-[calc(100vh-220px)] lg:h-auto py-4 sm:py-8 lg:py-0">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  def handle_event("validate", %{"author" => author_params}, socket) do
    changeset =
      Accounts.change_author_registration(socket.assigns.author, author_params)
      |> maybe_add_email_error(socket.assigns.author.email, author_params["email"])

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event(
        "save",
        %{"author" => author_params} = params,
        socket
      ) do
    %{author: author} = socket.assigns

    with {:success, true} <- Oli.Recaptcha.verify(params["g-recaptcha-response"]),
         {:emails_match?, true} <-
           {:emails_match?, emails_match?(author.email, author_params["email"])} do
      Accounts.accept_author_invitation(author, author_params)
      |> case do
        {:ok, _} ->
          {:noreply, socket |> assign(trigger_submit: true)}

        _ ->
          {:noreply,
           socket
           |> put_flash(:error, "An error occurred while processing your request.")}
      end
    else
      {:success, false} ->
        {:noreply,
         socket
         |> assign(recaptcha_error: "reCAPTCHA failed, please try again")
         |> assign_form(Accounts.change_author_registration(author, author_params))}

      {:emails_match?, false} ->
        # this clause prevents any form "hack" to change the email (even if that field is disabled)
        changeset =
          Accounts.change_author_registration(author, author_params)
          |> Ecto.Changeset.add_error(:email, "does not match the invitation email")
          |> Map.put(:action, :validate)

        {:noreply, assign_form(socket, changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}

      _ ->
        {:noreply,
         socket
         |> assign(check_errors: true)
         |> assign_form(Accounts.change_author_registration(author, author_params))}
    end
  end

  def handle_event("log_in_existing_author", params, socket) do
    %{author: author} = socket.assigns

    case Accounts.get_author_by_email_and_password(author.email, params["author"]["password"]) do
      nil ->
        {:noreply, put_flash(socket, :error, "Invalid email or password")}

      _author ->
        {:noreply, assign(socket, trigger_submit: true)}
    end
  end

  defp maybe_add_email_error(changeset, email, email_param) do
    if emails_match?(email, email_param) do
      changeset
    else
      Ecto.Changeset.add_error(changeset, :email, "does not match the invitation email")
    end
  end

  defp emails_match?(_author_email, email_param) when is_nil(email_param), do: true
  defp emails_match?(author_email, email_param), do: author_email == email_param

  defp new_invited_author?(%Author{password_hash: nil}), do: true
  defp new_invited_author?(_), do: false

  defp current_author_is_the_invited_one?(nil, _author), do: false

  defp current_author_is_the_invited_one?(current_author, author),
    do: current_author.id == author.id

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "author")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
