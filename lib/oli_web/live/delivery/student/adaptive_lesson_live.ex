defmodule OliWeb.Delivery.Student.AdaptiveLessonLive do
  use OliWeb, :live_view

  import OliWeb.Delivery.Student.Utils,
    only: [emit_page_viewed_event: 1]

  alias Oli.Accounts.User
  alias Oli.Delivery.Sections

  require Logger

  on_mount {OliWeb.LiveSessionPlugs.InitPage, :init_adaptive_context_state}

  # this is an optimization to reduce the memory footprint of the liveview process
  @required_keys_per_assign %{
    section:
      {[:id, :slug, :title, :brand, :lti_1p3_deployment, :customizations], %Sections.Section{}},
    current_user: {[:id, :name, :email], %User{}}
  }

  def mount(_params, _session, socket) do
    if connected?(socket) do
      emit_page_viewed_event(socket)
      send(self(), :gc)
    end

    {:ok, slim_assigns(socket), temporary_assigns: [page_context: %{}]}
  end

  def render(assigns) do
    ~H"""
    <!-- ACTIVITIES -->
    <%= for %{slug: slug, authoring_script: script} <- @activity_types do %>
      <script
        :if={slug == "oli_adaptive"}
        type="text/javascript"
        src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}
      >
      </script>
    <% end %>
    <!-- PARTS -->
    <script
      :for={script <- @part_scripts}
      type="text/javascript"
      src={Routes.static_path(OliWeb.Endpoint, "/js/" <> script)}
    >
    </script>

    <script type="text/javascript" src={Routes.static_path(OliWeb.Endpoint, "/js/delivery.js")}>
    </script>

    <div id="delivery_container" phx-update="ignore">
      <%= react_component("Components.Delivery", @app_params) %>
    </div>

    <%= OliWeb.LayoutView.additional_stylesheets(%{additional_stylesheets: @additional_stylesheets}) %>

    <script>
      window.userToken = "<%= @user_token %>";
    </script>
    """
  end

  defp slim_assigns(socket) do
    Enum.reduce(@required_keys_per_assign, socket, fn {assign_name, {required_keys, struct}},
                                                      socket ->
      assign(
        socket,
        assign_name,
        Map.merge(
          struct,
          Map.filter(socket.assigns[assign_name], fn {k, _v} -> k in required_keys end)
        )
      )
    end)
  end
end
