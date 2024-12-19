defmodule OliWeb.Users.Invitations.UsersInviteView do
  alias Oli.Accounts.UserToken
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections

  def mount(%{"token" => token}, session, socket) do
    case Accounts.get_user_token_by_enrollment_invitation_token(token) do
      nil ->
        {:ok, assign(socket, user: nil)}

      %UserToken{user: user, context: "enrollment_invitation:" <> section_slug} ->
        section = Sections.get_section_by_slug(section_slug)

        {:ok,
         assign(socket,
           user: user,
           # this current user refers to the one that is logged in
           # and might be different from the user that is being invited
           current_user:
             session["user_token"] && Accounts.get_user_by_session_token(session["user_token"]),
           section: section,
           enrollment: Sections.get_enrollment(section.slug, user.id, filter_by_status: false),
           step: "accept_or_reject_invitation"
         )}
    end
  end

  def render(%{user: nil} = assigns) do
    ~H"""
    This invitation has expired or does not exist.
    """
  end

  def render(%{enrollment: %{status: :rejected}} = assigns) do
    ~H"""
    This invitation has already been rejected.
    """
  end

  def render(%{enrollment: %{status: status}} = assigns) when status in [:enrolled, :suspended] do
    ~H"""
    This invitation has already been redeemed.
    """
  end

  def render(%{step: "accept_or_reject_invitation"} = assigns) do
    ~H"""
    <div class="flex flex-col w-full justify-center items-center">
      <h1>Invitation to <%= @section.title %></h1>

      <div class="flex gap-4">
        <.button type="button" phx-click="accept_invitation" class="btn btn-primary">Accept</.button>
        <.button type="button" phx-click="reject_invitation" class="btn btn-secondary">
          Reject invitation
        </.button>
      </div>
    </div>
    """
  end

  def render(%{step: "new_user_account_creation"} = assigns) do
    ~H"""
    <div class="flex flex-col w-full justify-center items-center">
      <h1>Invitation to <%= @section.title %></h1>

      <div class="w-full flex items-center justify-center dark">
        <Components.Auth.registration_form
          title="Create Account"
          form={@form}
          action={~p"/users/accept_invitation?email=#{@user.email}&section_slug=#{@section.slug}"}
          trigger_submit={@trigger_submit}
          recaptcha_error={@recaptcha_error}
          check_errors={@check_errors}
          disabled_inputs={[:email]}
        />
      </div>
    </div>
    """
  end

  def render(%{step: "existing_user_login"} = assigns) do
    ~H"""
    <div class="flex flex-col w-full justify-center items-center">
      <h1>Invitation to <%= @section.title %></h1>

      <div class="w-full flex items-center justify-center dark">
        <Components.Auth.login_form
          title="Sign In"
          form={@form}
          action={~p"/users/accept_invitation?email=#{@user.email}&section_slug=#{@section.slug}"}
          reset_password_link={~p"/users/reset_password"}
          trigger_submit={@trigger_submit}
          submit_event="log_in_existing_user"
          disabled_inputs={[:email]}
        />
      </div>

      <div :if={!is_nil(@current_user) && @current_user.id != @user.id} class="text-xs text-bold">
        <p>
          You are currently logged in as <strong><%= @current_user.email %></strong>.<br />
          You will be automatically logged in as <strong><%= @user.email %></strong>
          to access your invitation to <strong>"<%= @section.title %>"</strong>
          Course.
        </p>
      </div>
    </div>
    """
  end

  def handle_event("accept_invitation", _, socket) do
    %{
      current_user: current_user,
      user: user,
      enrollment: enrollment,
      section: section
    } =
      socket.assigns

    case {new_invited_user?(user), current_user_is_the_invited_one?(current_user, user)} do
      {true, _} ->
        # the new user must complete registration
        changeset = Accounts.change_user_registration(user)

        {:noreply,
         assign(socket,
           step: "new_user_account_creation",
           trigger_submit: false,
           check_errors: false,
           recaptcha_error: false
         )
         |> assign_form(changeset)}

      {false, true} ->
        # the already logged in user is the one being invited
        # we can just mark the enrollment as :enrolled
        # and redirect to the section
        Sections.update_enrollment(enrollment, %{status: :enrolled})

        {:noreply, redirect(socket, to: ~p"/sections/#{section.slug}")}

      {false, false} ->
        # the existing invited user is not logged in
        # we need to ask for the password
        form = to_form(%{"email" => user.email}, as: "user")

        {:noreply, assign(socket, step: "existing_user_login", form: form, trigger_submit: false)}
    end
  end

  def handle_event("reject_invitation", _, socket) do
    Sections.update_enrollment(socket.assigns.enrollment, %{status: :rejected})

    {:noreply,
     socket
     |> put_flash(:info, "Your invitation has been rejected.")
     |> redirect(to: ~p"/")}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Accounts.change_user_registration(socket.assigns.user, user_params)
      |> maybe_add_email_error(socket.assigns.user.email, user_params["email"])

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event(
        "save",
        %{"user" => user_params} = params,
        socket
      ) do
    %{user: user, enrollment: enrollment} = socket.assigns

    with {:success, true} <- Oli.Recaptcha.verify(params["g-recaptcha-response"]),
         {:emails_match?, true} <-
           {:emails_match?, emails_match?(user.email, user_params["email"])} do
      Accounts.accept_user_invitation(user, enrollment, user_params)
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
         |> assign_form(Accounts.change_user_registration(user, user_params))}

      {:emails_match?, false} ->
        # this clause prevents any form "hack" to change the email (even if that field is disabled)
        changeset =
          Accounts.change_user_registration(user, user_params)
          |> Ecto.Changeset.add_error(:email, "does not match the invitation email")
          |> Map.put(:action, :validate)

        {:noreply, assign_form(socket, changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}

      _ ->
        {:noreply,
         socket
         |> assign(check_errors: true)
         |> assign_form(Accounts.change_user_registration(user, user_params))}
    end
  end

  def handle_event("log_in_existing_user", params, socket) do
    %{user: user, enrollment: enrollment} = socket.assigns

    case Accounts.get_user_by_email_and_password(user.email, params["user"]["password"]) do
      nil ->
        {:noreply, put_flash(socket, :error, "Invalid email or password")}

      _user ->
        Sections.update_enrollment(enrollment, %{status: :enrolled})

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

  defp emails_match?(_user_email, email_param) when is_nil(email_param), do: true
  defp emails_match?(user_email, email_param), do: user_email == email_param

  defp new_invited_user?(%User{password_hash: nil, invited_by: invited_by_id})
       when not is_nil(invited_by_id),
       do: true

  defp new_invited_user?(_), do: false

  defp current_user_is_the_invited_one?(nil, _user), do: false
  defp current_user_is_the_invited_one?(current_user, user), do: current_user.id == user.id

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
