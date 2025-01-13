defmodule OliWeb.Collaborators.Invitations.InviteView do
  use OliWeb, :live_view

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Accounts.AuthorToken
  alias Oli.Authoring.Course

  import OliWeb.Backgrounds

  def mount(%{"token" => token}, session, socket) do
    case Accounts.get_author_token_by_collaboration_invitation_token(token) do
      nil ->
        {:ok, assign(socket, author: nil)}

      %AuthorToken{author: author, context: "collaborator_invitation:" <> project_slug} ->
        project = Course.get_project_by_slug(project_slug)

        {:ok,
         assign(socket,
           author: author,
           # this current author refers to the one that is logged in
           # and might be different from the author that is being invited
           current_author:
             session["author_token"] &&
               Accounts.get_author_by_session_token(session["author_token"]),
           project: project,
           # the author project is like the "enrollment" but for authors
           author_project:
             Course.get_author_project(project_slug, author.id, filter_by_status: false),
           step: "accept_or_reject_invitation"
         )}
    end
  end

  def render(%{author: nil} = assigns) do
    ~H"""
    <.invite_container>
      <h3 class="text-white">This invitation has expired or does not exist.</h3>
    </.invite_container>
    """
  end

  def render(%{author_project: %{status: :rejected}} = assigns) do
    ~H"""
    <.invite_container>
      <h3 class="text-white">This invitation has already been rejected.</h3>
    </.invite_container>
    """
  end

  def render(%{author_project: %{status: :accepted}} = assigns) do
    ~H"""
    <.invite_container>
      <h3 class="text-white">This invitation has already been redeemed.</h3>

      <.link
        class="flex items-center gap-x-1 no-underline hover:no-underline text-white hover:text-zinc-300"
        navigate={~p"/workspaces/course_author/#{@project.slug}/overview"}
      >
        <div class="text-xl font-normal font-['Inter'] leading-normal">
          Go to project
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
    <.invite_container>
      <h1 class="text-white">Invitation to <%= @project.title %></h1>

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

  def render(%{step: "new_author_account_creation"} = assigns) do
    ~H"""
    <.invite_container>
      <h1 class="text-white">Invitation to <%= @project.title %></h1>

      <div class="w-full flex items-center justify-center dark">
        <Components.Auth.registration_form
          title="Create Account"
          form={@form}
          action={
            ~p"/collaborators/accept_invitation?email=#{@author.email}&project_slug=#{@project.slug}"
          }
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
      <h1 class="text-white">Invitation to <%= @project.title %></h1>

      <div class="w-full flex items-center justify-center dark">
        <Components.Auth.login_form
          title="Sign In"
          form={@form}
          action={
            ~p"/collaborators/accept_invitation?email=#{@author.email}&project_slug=#{@project.slug}"
          }
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
          You will be automatically logged in as <strong><%= @author.email %></strong>
          to access your invitation to <strong>"<%= @project.title %>"</strong>
          Course.
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
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def handle_event("accept_invitation", _, socket) do
    %{
      current_author: current_author,
      author: author,
      author_project: author_project,
      project: project
    } =
      socket.assigns

    case {new_invited_author?(author), current_author_is_the_invited_one?(current_author, author)} do
      {true, _} ->
        # the new author must complete registration
        changeset = Accounts.change_author_registration(author)

        {:noreply,
         assign(socket,
           step: "new_author_account_creation",
           trigger_submit: false,
           check_errors: false,
           recaptcha_error: false
         )
         |> assign_form(changeset)}

      {false, true} ->
        # the already logged in author is the one being invited
        # we can just mark the author_project as :accepted
        # and redirect to the project
        Course.update_author_project(author_project, %{status: :accepted})

        {:noreply, redirect(socket, to: ~p"/workspaces/course_author/#{project.slug}/overview")}

      {false, false} ->
        # the existing invited author is not logged in
        # we need to ask for the password
        form = to_form(%{"email" => author.email}, as: "author")

        {:noreply,
         assign(socket, step: "existing_author_login", form: form, trigger_submit: false)}
    end
  end

  def handle_event("reject_invitation", _, socket) do
    Course.update_author_project(socket.assigns.author_project, %{status: :rejected})

    {:noreply,
     socket
     |> put_flash(:info, "Your invitation has been rejected.")
     |> redirect(to: ~p"/authors/log_in")}
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
    %{author: author, author_project: author_project} = socket.assigns

    with {:success, true} <- Oli.Recaptcha.verify(params["g-recaptcha-response"]),
         {:emails_match?, true} <-
           {:emails_match?, emails_match?(author.email, author_params["email"])} do
      Accounts.accept_author_invitation(author, author_project, author_params)
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
    %{author: author, author_project: author_project} = socket.assigns

    case Accounts.get_author_by_email_and_password(author.email, params["author"]["password"]) do
      nil ->
        {:noreply, put_flash(socket, :error, "Invalid email or password")}

      _author ->
        Course.update_author_project(author_project, %{status: :accepted})

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
