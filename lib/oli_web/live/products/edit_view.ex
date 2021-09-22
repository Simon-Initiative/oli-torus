defmodule OliWeb.Products.EditView do
  use Surface.LiveView

  alias Oli.Repo
  alias OliWeb.Common.Breadcrumb
  alias Oli.Accounts.Author
  alias Oli.Delivery.Sections.Section
  alias Oli.Delivery.Sections
  alias Oli.Delivery.Sections.Blueprint
  import Phoenix.HTML.Form
  import OliWeb.ErrorHelpers
  alias Oli.Branding

  data breadcrumbs, :any, default: [Breadcrumb.new(%{full_title: "Edit Product"})]
  data product, :any, default: nil
  data changeset, :any, default: nil
  prop author, :any
  prop available_brands, :list

  defp statuses do
    [{"Active", "active"}, {"Disabled", "deleted"}]
  end

  defp strategies do
    [
      {"Relative to section start", "relative_to_section"},
      {"Relative to student first access", "relative_to_student"}
    ]
  end

  def mount(%{"product_id" => product_slug}, %{"current_author_id" => author_id}, socket) do
    author = Repo.get(Author, author_id)
    product = Blueprint.get_blueprint(product_slug)

    available_brands =
      Branding.list_brands()
      |> Enum.map(fn brand -> {brand.name, brand.id} end)

    {:ok,
     assign(socket,
       available_brands: available_brands,
       author: author,
       product: product,
       changeset: Section.changeset(product, %{}),
       title: "Edit Product"
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.form let={f} for={@changeset} phx-change="validate" phx-submit="save" action="#">

        <h5 class="mb-3">Product Details</h5>

        <div class="form-row">

          <div class="form-group" style="width: 80%;">
            <%= label f, :title %>
            <%= text_input f, :title, class: "form-control" %>
            <div><%= error_tag f, :title %></div>
          </div>

          <div class="form-group ml-3">
            <%= label f, :status %>
            <%= select f, :status, statuses(), class: "form-control " <> error_class(f, :status, "is-invalid"),
              autofocus: focusHelper(f, :status) %>
            <div><%= error_tag f, :status %></div>
          </div>

        </div>

        <div class="form-group">
          <%= label f, :description %>
          <%= text_input f, :description, class: "form-control" %>
          <div><%= error_tag f, :description %></div>
        </div>

        <h5 class="mt-5 mb-3">Paywall Settings</h5>

        <div class="form-row">

          <div class="custom-control custom-switch" style="width: 200px;">
            <%= checkbox f, :requires_payment, class: "custom-control-input" <> error_class(f, :requires_payment, "is-invalid"), autofocus: focusHelper(f, :requires_payment) %>
            <%= label f, :requires_payment, "Requires Payment", class: "custom-control-label" %>
            <%= error_tag f, :requires_payment %>
          </div>

          <div class="form-group">
            <%= label f, :amount %>
            <%= text_input f, :amount, class: "form-control" %>
            <div><%= error_tag f, :amount %></div>
          </div>

        </div>

        <div class="form-row">

          <div class="custom-control custom-switch" style="width: 200px;">
            <%= checkbox f, :has_grace_period, class: "custom-control-input" <> error_class(f, :has_grace_period, "is-invalid"), autofocus: focusHelper(f, :requires_payment) %>
            <%= label f, :has_grace_period, "Has Grace Period", class: "custom-control-label" %>
            <%= error_tag f, :has_grace_period %>
          </div>

          <div class="form-group" style="max-width: 200px;">
            <%= label f, :grace_period_days %>
            <%= text_input f, :grace_period_days, type: :number, class: "form-control" %>
            <div><%= error_tag f, :grace_period_days %></div>
          </div>

          <div class="form-group ml-3" style="max-width: 230px;">
            <%= label f, :grace_period_strategy %>
            <%= select f, :grace_period_strategy, strategies(), class: "form-control " <> error_class(f, :grace_period_strategy, "is-invalid"),
              autofocus: focusHelper(f, :grace_period_strategy) %>
            <div><%= error_tag f, :grace_period_strategy %></div>
          </div>

        </div>

        <%= submit "Save", class: "btn btn-primary" %>
      </.form>
    </div>

    """
  end

  def handle_event("validate", %{"section" => params}, socket) do
    changeset =
      socket.assigns.product
      |> Sections.change_section(params)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("save", %{"section" => params}, socket) do
    case Sections.update_section(socket.assigns.product, params) do
      {:ok, section} ->
        socket = put_flash(socket, :info, "Product changes saved")

        {:noreply, assign(socket, product: section, changeset: Section.changeset(section, %{}))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end
end
