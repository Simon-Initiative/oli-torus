defmodule OliWeb.Users.AuthorsDetailView do
  use OliWeb, :live_view
  use OliWeb.Common.Modal

  require Logger

  import OliWeb.Common.Utils

  alias Oli.Accounts
  alias Oli.Accounts.{Author, SystemRole}
  alias Oli.Auditing
  alias Oli.Repo
  alias OliWeb.Users.DetailViewHelpers

  alias OliWeb.Accounts.Modals.{
    LockAccountModal,
    UnlockAccountModal,
    DeleteAccountModal,
    ConfirmEmailModal
  }

  alias OliWeb.Common.Breadcrumb
  alias OliWeb.Common.Properties.{Groups, ReadOnly}
  alias OliWeb.Icons
  alias OliWeb.Router.Helpers, as: Routes
  alias OliWeb.Users.Actions

  on_mount {OliWeb.AuthorAuth, :ensure_authenticated}
  on_mount OliWeb.LiveSessionPlugs.SetCtx

  defp set_breadcrumbs(author) do
    OliWeb.Admin.AdminView.breadcrumb()
    |> OliWeb.Users.AuthorsView.breadcrumb()
    |> breadcrumb(author)
  end

  def breadcrumb(previous, %Author{id: id} = author) do
    name = name(author.name, author.given_name, author.family_name)

    previous ++
      [
        Breadcrumb.new(%{
          full_title: name,
          link: Routes.live_path(OliWeb.Endpoint, __MODULE__, id)
        })
      ]
  end

  def mount(
        %{"author_id" => author_id},
        _session,
        socket
      ) do
    case Accounts.get_author(author_id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Author not found")
         |> redirect(to: ~p"/admin/authors")}

      author ->
        author = Repo.preload(author, :user_identities)
        has_google = DetailViewHelpers.credentials_has_google?(author.user_identities)

        {:ok,
         assign(socket,
           current_author: socket.assigns.current_author,
           breadcrumbs: set_breadcrumbs(author),
           author: author,
           disabled_edit: true,
           author_roles: SystemRole.role_id(),
           credentials_has_google: has_google,
           credentials_label: DetailViewHelpers.credentials_label(author, has_google),
           password_reset_link: "",
           author_name: author.name,
           author_header_name: DetailViewHelpers.formatted_header_name(author),
           form: author_form(author)
         )}
    end
  end

  attr(:current_author, Author, required: true)
  attr(:breadcrumbs, :any)
  attr(:title, :string, default: "Author Details")
  attr(:author, Author, required: true)
  attr(:modal, :any, default: nil)
  attr(:disabled_edit, :boolean, default: true)
  attr(:disabled_submit, :boolean, default: false)
  attr(:author_roles, :map, default: %{})
  attr(:password_reset_link, :string)
  attr(:author_name, :string)
  attr(:author_header_name, :string)
  attr(:form, :map)
  attr(:credentials_has_google, :boolean)
  attr(:credentials_label, :string)

  def render(assigns) do
    ~H"""
    <div>
      {render_modal(assigns)}

      <Groups.render>
        <div class="pt-6 pb-2">
          <h2 class="text-Text-text-high text-2xl font-semibold leading-8">
            {if @author_header_name == "", do: "Unnamed author", else: @author_header_name}
          </h2>
        </div>
        <div class="flex flex-col py-5 border-b border-Border-border-subtle">
          <h4>Projects</h4>
          <div class="text-Text-text-low-alpha">
            Projects that the Author has either created or is a collaborator within
          </div>
          <div class="mt-4">
            <.live_component
              module={OliWeb.Users.AuthorProjects}
              id="author_projects"
              user={@author}
              ctx={@ctx}
            />
          </div>
        </div>

        <div class="grid grid-cols-1 gap-8 py-5 border-b border-Border-border-subtle lg:grid-cols-2">
          <div class="flex flex-col">
            <h4>Details</h4>
            <div class="text-Text-text-low-alpha">User details</div>
            <div class="mt-4">
              <.form
                id="edit_author"
                for={@form}
                phx-change="change"
                phx-submit="submit"
                autocomplete="off"
              >
                <div class="flex flex-col gap-4">
                  <ReadOnly.render label="Name" value={@author_name} />
                  <div class="form-group">
                    <label for="given_name">First Name</label>
                    <.input
                      field={@form[:given_name]}
                      id="given_name"
                      class="form-control"
                      disabled={@disabled_edit}
                      error_position={:bottom}
                    />
                  </div>
                  <div class="form-group">
                    <label for="family_name">Last Name</label>
                    <.input
                      field={@form[:family_name]}
                      id="family_name"
                      class="form-control"
                      disabled={@disabled_edit}
                      error_position={:bottom}
                    />
                  </div>
                  <div class="form-group">
                    <label for="email">Email</label>
                    <.input
                      field={@form[:email]}
                      id="email"
                      class="form-control"
                      disabled={@disabled_edit}
                      error_position={:bottom}
                    />
                  </div>
                  <div class="form-group">
                    <label for="role">Role</label>
                    <.input
                      type="select"
                      class="form-control"
                      field={@form[:system_role_id]}
                      options={
                        Enum.map(@author_roles, fn {_type, id} ->
                          {role(id), id}
                        end)
                      }
                      disabled={
                        @disabled_edit or not Accounts.has_admin_role?(@current_author, :system_admin)
                      }
                    />
                  </div>
                  <%= if Accounts.has_admin_role?(@current_author, :system_admin) do %>
                    <div class="form-control">
                      <.input
                        type="checkbox"
                        field={@form[:is_internal]}
                        label="Internal staff"
                        class="form-check-input"
                        disabled={@disabled_edit}
                      />
                      <p class="mt-1 text-xs text-Text-text-low-alpha">
                        Internal actors gain early access to internal-only and canary features.
                      </p>
                    </div>
                  <% else %>
                    <ReadOnly.render
                      label="Internal actor"
                      value={if(@author.is_internal, do: "Yes", else: "No")}
                    />
                  <% end %>
                  <div class="form-group">
                    <span class="form-label">Credentials Managed By</span>
                    <div class="mt-2 flex flex-col gap-2 text-Text-text-low-alpha">
                      <%= if @credentials_has_google do %>
                        <div class="flex flex-col items-start gap-1">
                          <Icons.google />
                          <span class="text-[11px] uppercase tracking-wide text-Text-text-low-alpha">
                            Google
                          </span>
                        </div>
                      <% end %>
                      <%= if @credentials_label do %>
                        <span class="text-sm font-semibold text-Text-text-high">
                          {@credentials_label}
                        </span>
                      <% end %>
                      <%= if !@credentials_has_google && is_nil(@credentials_label) do %>
                        <span class="text-sm text-Text-text-low-alpha">None</span>
                      <% end %>
                    </div>
                  </div>
                </div>
                <%= unless @disabled_edit do %>
                  <div class="mt-4 flex justify-end">
                    <.button
                      variant={:primary}
                      type="submit"
                      size={:sm}
                      class="!bg-Fill-Buttons-fill-primary hover:!bg-Fill-Buttons-fill-primary-hover"
                      disabled={@disabled_submit}
                    >
                      Save
                    </.button>
                  </div>
                <% end %>
              </.form>
              <%= if @disabled_edit do %>
                <div class="mt-4 flex justify-end">
                  <.button
                    variant={:primary}
                    size={:sm}
                    class="!bg-Fill-Buttons-fill-primary hover:!bg-Fill-Buttons-fill-primary-hover"
                    phx-click="start_edit"
                  >
                    Edit
                  </.button>
                </div>
              <% end %>
            </div>
          </div>
          <div class="flex flex-col">
            <h4>Actions</h4>
            <div class="text-Text-text-low-alpha">Actions that can be taken for this user</div>
            <div class="mt-4 w-full max-w-[535px]">
              <%= if @author.id != @current_author.id and @author.email != System.get_env("ADMIN_EMAIL", "admin@example.edu") do %>
                <Actions.render
                  user_id={@author.id}
                  account_locked={!is_nil(@author.locked_at)}
                  email_confirmation_pending={Accounts.author_confirmation_pending?(@author)}
                  password_reset_link={@password_reset_link}
                />
              <% end %>
            </div>
          </div>
        </div>
      </Groups.render>
    </div>
    """
  end

  def handle_event("generate_reset_password_link", %{"id" => id}, socket) do
    author = Accounts.get_author!(id)

    encoded_token = Accounts.generate_author_reset_password_token(author)

    password_reset_link =
      url(~p"/authors/reset_password/#{encoded_token}")

    socket = assign(socket, password_reset_link: password_reset_link)
    {:noreply, socket}
  end

  def handle_event("show_confirm_email_modal", _, socket) do
    modal_assigns = %{
      author: socket.assigns.author
    }

    modal = fn assigns ->
      ~H"""
      <ConfirmEmailModal.render id="confirm_email" user={@author} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event(
        "confirm_email",
        _,
        socket
      ) do
    case Accounts.admin_confirm_author(socket.assigns.author) do
      {:ok, author} ->
        {:noreply,
         socket
         |> assign(author: author)
         |> hide_modal(modal_assigns: nil)}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Error confirming author's email")}
    end
  end

  def handle_event("resend_confirmation_link", %{"id" => id}, socket) do
    author = Accounts.get_author!(id)

    case Accounts.deliver_author_confirmation_instructions(
           author,
           &url(~p"/authors/confirm/#{&1}")
         ) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Confirmation link sent.")}

      {:error, :already_confirmed} ->
        {:noreply, put_flash(socket, :info, "Email is already confirmed.")}
    end
  end

  def handle_event("send_reset_password_link", %{"id" => id}, socket) do
    author = Accounts.get_author!(id)

    case Accounts.deliver_author_reset_password_instructions(
           author,
           &url(~p"/authors/reset_password/#{&1}")
         ) do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Password reset link sent.")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, "Error sending password reset link: #{error}")}
    end
  end

  def handle_event("show_lock_account_modal", _, socket) do
    modal_assigns = %{
      author: socket.assigns.author
    }

    modal = fn assigns ->
      ~H"""
      <LockAccountModal.render id="lock_account" user={@author} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event(
        "lock_account",
        %{"id" => id},
        socket
      ) do
    author = Accounts.get_author!(id)

    case Accounts.lock_author(author) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(author: Accounts.get_author!(id))
         |> hide_modal(modal_assigns: nil)}

      {:error, _error} ->
        {:noreply,
         put_flash(socket, :error, "Failed to lock author account.")
         |> hide_modal(modal_assigns: nil)}
    end
  end

  def handle_event("show_unlock_account_modal", _, socket) do
    modal_assigns = %{
      author: socket.assigns.author
    }

    modal = fn assigns ->
      ~H"""
      <UnlockAccountModal.render id="unlock_account" user={@author} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event(
        "unlock_account",
        %{"id" => id},
        socket
      ) do
    author = Accounts.get_author!(id)

    case Accounts.unlock_author(author) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(author: Accounts.get_author!(id))
         |> hide_modal(modal_assigns: nil)}

      {:error, _error} ->
        {:noreply,
         put_flash(socket, :error, "Failed to unlock author account.")
         |> hide_modal(modal_assigns: nil)}
    end
  end

  def handle_event("show_delete_account_modal", _, socket) do
    modal_assigns = %{
      author: socket.assigns.author
    }

    modal = fn assigns ->
      ~H"""
      <DeleteAccountModal.render id="delete_account" user={@author} />
      """
    end

    {:noreply, show_modal(socket, modal, modal_assigns: modal_assigns)}
  end

  def handle_event(
        "delete_account",
        %{"id" => id},
        socket
      ) do
    author = Accounts.get_author!(id)
    admin = socket.assigns.current_author

    case Accounts.delete_author(author) do
      {:ok, deleted_author} ->
        # Log the deletion
        Oli.Auditing.log_admin_action(
          admin,
          :author_deleted,
          deleted_author,
          %{
            "email" => deleted_author.email,
            "name" => deleted_author.name,
            "deleted_by" => admin.email
          }
        )

        {:noreply,
         socket
         |> hide_modal(modal_assigns: nil)
         |> put_flash(:info, "Author successfully deleted.")
         |> push_navigate(to: Routes.live_path(OliWeb.Endpoint, OliWeb.Users.AuthorsView))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Author couldn't be deleted.")}
    end
  end

  def handle_event("change", %{"author" => params}, socket) do
    form = author_form(socket.assigns.author, params)

    author_name = combined_name_from_form(form, socket.assigns.author)
    author_header_name = combined_header_name_from_form(form, socket.assigns.author)

    socket =
      socket
      |> assign(form: form)
      |> assign(disabled_submit: !Enum.empty?(form.errors))
      |> assign(author_name: author_name)
      |> assign(author_header_name: author_header_name)

    {:noreply, socket}
  end

  def handle_event("submit", %{"author" => params}, socket) do
    admin? = Accounts.has_admin_role?(socket.assigns.current_author, :system_admin)
    filtered_params = if admin?, do: params, else: Map.delete(params, "is_internal")
    previous_author = socket.assigns.author

    case Accounts.admin_update_author(previous_author, filtered_params) do
      {:ok, author} ->
        updated_form = author_form(author, params)

        maybe_audit_internal_toggle(
          socket.assigns.current_author,
          :author,
          previous_author,
          author
        )

        {:noreply,
         socket
         |> put_flash(:info, "Author successfully updated.")
         |> assign(
           author: author,
           form: updated_form,
           disabled_edit: true,
           author_name: combined_name_from_form(updated_form, author),
           author_header_name: combined_header_name_from_form(updated_form, author)
         )}

      {:error, error} ->
        form = to_form(error)

        {:noreply,
         socket
         |> assign(form: form)
         |> assign(disabled_submit: !Enum.empty?(form.errors))
         |> put_flash(:error, "Author couldn't be updated.")}
    end
  end

  def handle_event("start_edit", _, socket) do
    {:noreply, socket |> assign(disabled_edit: false)}
  end

  @impl Phoenix.LiveView
  def handle_event(event, params, socket) do
    # Catch-all for UI-only events from functional components
    # that don't need handling (like dropdown toggles)
    Logger.warning("Unhandled event in AuthorDetailView: #{inspect(event)}, #{inspect(params)}")
    {:noreply, socket}
  end

  defp maybe_audit_internal_toggle(admin, :author, %Author{} = previous, %Author{} = updated) do
    cond do
      is_nil(admin) ->
        :ok

      previous.is_internal == updated.is_internal ->
        :ok

      true ->
        Auditing.capture(
          admin,
          :account_internal_flag_changed,
          updated,
          %{
            "account_type" => "author",
            "author_id" => updated.id,
            "previous" => previous.is_internal,
            "is_internal" => updated.is_internal
          }
        )

        :ok
    end
  end

  defp combined_name_from_form(form, fallback_author) do
    given = form[:given_name].value || fallback_author.given_name || ""
    family = form[:family_name].value || fallback_author.family_name || ""

    [given, family]
    |> Enum.reject(&(is_nil(&1) or &1 == ""))
    |> Enum.join(" ")
    |> case do
      "" -> fallback_author.name || ""
      name -> name
    end
  end

  defp combined_header_name_from_form(form, fallback_author) do
    given = form[:given_name].value || fallback_author.given_name || ""
    family = form[:family_name].value || fallback_author.family_name || ""

    case {String.trim(family), String.trim(given)} do
      {"", ""} -> fallback_author.name || ""
      {family, ""} -> family
      {"", given} -> given
      {family, given} -> "#{family}, #{given}"
    end
  end

  defp author_form(author, attrs \\ %{}) do
    author
    |> Author.noauth_changeset(attrs)
    |> Map.put(:action, :update)
    |> to_form()
  end

  defp role(system_role_id) do
    admin_role_id = SystemRole.role_id().system_admin
    account_role_id = SystemRole.role_id().account_admin
    content_role_id = SystemRole.role_id().content_admin

    case system_role_id do
      ^admin_role_id ->
        "System Admin"

      ^account_role_id ->
        "Account Admin"

      ^content_role_id ->
        "Content Admin"

      _ ->
        "Author"
    end
  end
end
