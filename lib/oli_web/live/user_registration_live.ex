defmodule OliWeb.UserRegistrationLive do
  use OliWeb, :live_view

  import OliWeb.Backgrounds

  alias Oli.Accounts
  alias Oli.Accounts.User
  alias Oli.Recaptcha

  def render(assigns) do
    ~H"""
    <div class="relative h-[calc(100vh-112px)] flex justify-center items-center">
      <div class="absolute h-[calc(100vh-112px)] w-full top-0 left-0">
        <.student_sign_in />
      </div>
      <div class="flex flex-col gap-y-10 lg:flex-row w-full relative z-50 overflow-y-scroll lg:overflow-y-auto h-[calc(100vh-270px)] md:h-[calc(100vh-220px)] lg:h-auto py-4 sm:py-8 lg:py-0">
        <div class="w-full flex items-center justify-center dark">
          <Components.Auth.registration_form
            title="Create Account"
            form={@form}
            action={~p"/users/log_in?_action=registered&#{maybe_section_param(@section)}"}
            log_in_link={~p"/users/log_in"}
            authentication_providers={@authentication_providers}
            auth_provider_path_fn={&build_auth_provider_path(&1, @section, @from_invitation_link?)}
            trigger_submit={@trigger_submit}
            check_errors={@check_errors}
            recaptcha_error={@recaptcha_error}
            from_invitation_link?={@from_invitation_link?}
            section={@section}
          />
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration(%User{})

    authentication_providers =
      Oli.AssentAuth.UserAssentAuth.authentication_providers() |> Keyword.keys()

    socket =
      socket
      |> assign(
        trigger_submit: false,
        check_errors: false,
        recaptcha_error: false,
        authentication_providers: authentication_providers,
        from_invitation_link?: false,
        section: nil
      )
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_params(unsigned_params, _uri, socket) do
    from_invitation_link? = unsigned_params["from_invitation_link?"] == "true"
    section = unsigned_params["section"]

    {:noreply,
     assign(socket,
       from_invitation_link?: from_invitation_link?,
       section: section
     )}
  end

  def handle_event(
        "save",
        %{"user" => user_params} = params,
        socket
      ) do
    with {:success, true} <- Recaptcha.verify(params["g-recaptcha-response"]),
         {:ok, user} <- Accounts.register_independent_user(user_params) do
      {:ok, _} =
        Accounts.deliver_user_confirmation_instructions(
          user,
          &url(~p"/users/confirm/#{&1}?#{maybe_section_param(user_params["section"])}")
        )

      changeset = Accounts.change_user_registration(user)
      {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}
    else
      {:success, false} ->
        {:noreply,
         socket
         |> assign(recaptcha_error: "reCAPTCHA failed, please try again")
         |> assign_form(Accounts.change_user_registration(%User{}, user_params))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}

      _ ->
        {:noreply,
         socket
         |> assign(check_errors: true)
         |> assign_form(Accounts.change_user_registration(%User{}, user_params))}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Accounts.change_user_registration(%User{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end

  defp maybe_section_param(nil), do: []
  defp maybe_section_param(section), do: [section: section]

  defp build_auth_provider_path(provider, section, from_invitation_link?) do
    base_path = ~p"/users/auth/#{provider}/new"

    params =
      []
      |> maybe_add_param("section", section)
      |> maybe_add_param("from_invitation_link?", from_invitation_link?)
      |> URI.encode_query()

    if params == "", do: base_path, else: "#{base_path}?#{params}"
  end

  defp maybe_add_param(params, _key, nil), do: params
  defp maybe_add_param(params, _key, false), do: params
  defp maybe_add_param(params, key, value), do: [{key, value} | params]
end
