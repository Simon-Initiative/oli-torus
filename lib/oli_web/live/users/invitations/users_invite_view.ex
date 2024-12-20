defmodule OliWeb.Users.Invitations.UsersInviteView do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.Accounts.UserToken
  alias Oli.Delivery.Sections

  import OliWeb.Backgrounds

  def mount(%{"token" => token}, session, socket) do
    case Accounts.get_user_token_by_enrollment_invitation_token(token) do
      nil ->
        {:ok, assign(socket, user: nil)}

      %UserToken{user: user, context: "enrollment_invitation:" <> section_slug} ->
        section = Sections.get_section_by_slug(section_slug)

        enrollment =
          Sections.get_enrollment(section.slug, user.id, filter_by_status: false)
          |> Oli.Repo.preload([:context_roles])

        {:ok,
         assign(socket,
           user: user,
           # this current user refers to the one that is logged in
           # and might be different from the user that is being invited
           current_user:
             session["user_token"] && Accounts.get_user_by_session_token(session["user_token"]),
           section: section,
           enrollment: enrollment,
           invitation_role:
             if(hd(enrollment.context_roles).id == 4, do: :student, else: :instructor),
           step: "accept_or_reject_invitation"
         )}
    end
  end

  def render(%{user: nil} = assigns) do
    ~H"""
    <.invite_container invitation_role={@invitation_role}>
      <h3 class="text-white">This invitation has expired or does not exist.</h3>
    </.invite_container>
    """
  end

  def render(%{enrollment: %{status: :rejected}} = assigns) do
    ~H"""
    <.invite_container invitation_role={@invitation_role}>
      <h3 class="text-white">This invitation has already been rejected.</h3>
    </.invite_container>
    """
  end

  def render(%{enrollment: %{status: status}} = assigns) when status in [:enrolled, :suspended] do
    ~H"""
    <.invite_container invitation_role={@invitation_role}>
      <h3 class="text-white">This invitation has already been redeemed.</h3>

      <.link
        class="flex items-center gap-x-1 no-underline hover:no-underline text-white hover:text-zinc-300"
        navigate={~p"/sections/#{@section.slug}"}
      >
        <div class="text-xl font-normal font-['Inter'] leading-normal">
          Go to course
        </div>
        <div>
          <%= OliWeb.Icons.right_arrow_login(%{}) %>
        </div>
      </.link>
    </.invite_container>
    """
  end

  def render(%{step: "accept_or_reject_invitation"} = assigns) do
    ~H"""
    <.invite_container invitation_role={@invitation_role}>
      <h1 class="text-white">Invitation to <%= @section.title %></h1>

      <div class="flex gap-4">
        <.button type="button" phx-click="accept_invitation" class="btn btn-primary">
          Accept
        </.button>
        <.button type="button" phx-click="reject_invitation" class="btn btn-secondary">
          Reject invitation
        </.button>
      </div>
    </.invite_container>
    """
  end

  def render(%{step: "new_user_account_creation"} = assigns) do
    ~H"""
    <.invite_container invitation_role={@invitation_role}>
      <h1 class="text-white">Invitation to <%= @section.title %></h1>

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
    </.invite_container>
    """
  end

  def render(%{step: "existing_user_login"} = assigns) do
    ~H"""
    <.invite_container invitation_role={@invitation_role}>
      <h1 class="text-white">Invitation to <%= @section.title %></h1>

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
        <p class="text-white">
          You are currently logged in as <strong><%= @current_user.email %></strong>.<br />
          You will be automatically logged in as <strong><%= @user.email %></strong>
          to access your invitation to <strong>"<%= @section.title %>"</strong>
          Course.
        </p>
      </div>
    </.invite_container>
    """
  end

  slot :inner_block
  attr :invitation_role, :atom, required: true

  def invite_container(assigns) do
    ~H"""
    <div class="relative h-[calc(100vh-180px)] w-full flex justify-center items-center">
      <div class="absolute h-[calc(100vh-180px)] w-full top-0 left-0">
        <.background_by_role invitation_role={@invitation_role} />
      </div>
      <div class="flex flex-col justify-center items-center gap-y-10 w-full relative z-50 overflow-y-scroll lg:overflow-y-auto h-[calc(100vh-270px)] md:h-[calc(100vh-220px)] lg:h-auto py-4 sm:py-8 lg:py-0">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  attr :invitation_role, :atom, required: true

  def background_by_role(%{invitation_role: :student} = assigns) do
    ~H"""
    <.student_invitation />
    """
  end

  def background_by_role(%{invitation_role: :instructor} = assigns) do
    ~H"""
    <.instructor_invitation />
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
