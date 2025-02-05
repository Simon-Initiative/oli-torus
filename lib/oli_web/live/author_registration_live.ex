defmodule OliWeb.AuthorRegistrationLive do
  use OliWeb, :live_view

  import OliWeb.Backgrounds

  alias Oli.Accounts
  alias Oli.Accounts.Author
  alias Oli.Utils.Recaptcha

  def render(assigns) do
    ~H"""
    <div class="relative h-[calc(100vh-112px)] flex justify-center items-center">
      <div class="absolute h-[calc(100vh-112px)] w-full top-0 left-0">
        <.author_sign_in />
      </div>
      <div class="flex flex-col gap-y-10 lg:flex-row w-full relative z-50 overflow-y-scroll lg:overflow-y-auto h-[calc(100vh-270px)] md:h-[calc(100vh-220px)] lg:h-auto py-4 sm:py-8 lg:py-0">
        <div class="w-full flex items-center justify-center dark">
          <Components.Auth.registration_form
            title="Create Author Account"
            form={@form}
            action={~p"/authors/log_in?_action=registered"}
            log_in_link={~p"/authors/log_in"}
            authentication_providers={@authentication_providers}
            auth_provider_path_fn={&~p"/authors/auth/#{&1}/new"}
            trigger_submit={@trigger_submit}
            check_errors={@check_errors}
            recaptcha_error={@recaptcha_error}
          />
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_author_registration(%Author{})

    authentication_providers =
      Oli.AssentAuth.AuthorAssentAuth.authentication_providers() |> Keyword.keys()

    socket =
      socket
      |> assign(
        trigger_submit: false,
        check_errors: false,
        recaptcha_error: false,
        authentication_providers: authentication_providers
      )
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event(
        "save",
        %{"author" => author_params} = params,
        socket
      ) do
    with {:success, true} <- Recaptcha.verify(params["g-recaptcha-response"]),
         {:ok, author} <- Accounts.register_author(author_params) do
      {:ok, _} =
        Accounts.deliver_author_confirmation_instructions(
          author,
          &url(~p"/authors/confirm/#{&1}")
        )

      changeset = Accounts.change_author_registration(author)
      {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}
    else
      {:success, false} ->
        {:noreply,
         socket
         |> assign(recaptcha_error: "reCAPTCHA failed, please try again")
         |> assign_form(Accounts.change_author_registration(%Author{}, author_params))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}

      _ ->
        {:noreply,
         socket
         |> assign(check_errors: true)
         |> assign_form(Accounts.change_author_registration(%Author{}, author_params))}
    end
  end

  def handle_event("validate", %{"author" => author_params}, socket) do
    changeset = Accounts.change_author_registration(%Author{}, author_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "author")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
