defmodule OliWeb.Users.Invitations.UsersInviteView do
  alias Oli.Accounts.UserToken
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.Delivery.Sections

  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_token_by_enrollment_invitation_token(token) do
      nil ->
        {:ok, assign(socket, user: nil)}

      %UserToken{user: user, context: "enrollment_invitation:" <> section_slug} ->
        section = Sections.get_section_by_slug(section_slug)

        {:ok,
         assign(socket,
           user: user,
           new_invited_user?: new_invited_user?(user),
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
          action={
            ~p"/users/log_in?_action=invitation_accepted&email=#{@user.email}&section=#{@section.slug}"
          }
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
        TODO: login form here
      </div>
    </div>
    """
  end

  def handle_event("accept_invitation", _, socket) do
    if socket.assigns.new_invited_user? do
      # the new user must complete registration
      changeset = Accounts.change_user_registration(socket.assigns.user)

      {:noreply,
       assign(socket,
         step: "new_user_account_creation",
         trigger_submit: false,
         check_errors: false,
         recaptcha_error: false
       )
       |> assign_form(changeset)}
    else
      # TODO:

      # the user is already registered.
      # if it is not signed in, we need to ask for the password
      # if it is signed in, we can just mark the enrollment as :enrolled
      # and redirect to the section

      # Sections.update_enrollment(socket.assigns.enrollment, %{status: :enrolled})

      {:noreply, assign(socket, step: "existing_user_login")}
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

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
