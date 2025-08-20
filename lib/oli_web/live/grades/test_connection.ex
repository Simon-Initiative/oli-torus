defmodule OliWeb.Grades.TestConnection do
  use OliWeb, :html

  attr :section, Oli.Delivery.Sections.Section
  attr :test_output, :list

  def render(assigns) do
    ~H"""
    <div class="card">
      <div class="card-body">
        <h5 class="card-title">Test LMS Connection</h5>

        <p class="card-text">Test your LMS LTI connection and settings here.</p>

        <%= if !@section.grade_passback_enabled do %>
          <div class="alert alert-danger" role="alert">
            <h4 class="alert-heading">LTI Assignment and Grade Services Not Enabled!</h4>
            <p>
              Grade passback is not properly set up for this course section. Student grades
              <strong>will not</strong>
              be sent back to the LMS until this service is enabled.
            </p>

            <p>To enable this service, ensure that all of the following scopes
              are present in your LMS configuration:</p>

            <ul>
              <%= for scope <- Lti_1p3.Tool.Services.AGS.required_scopes() do %>
                <li><code>{scope}</code></li>
              <% end %>
            </ul>
          </div>
        <% end %>

        <%= if !@section.nrps_enabled do %>
          <div class="alert alert-info" role="alert">
            <h4 class="alert-heading">LTI Names and Role Provisioning Services Not Enabled</h4>
            <p>
              LTI Names and Role Provisioning Services is not enabled for this course section.  While this is not
              required to allow grade passback to operate, enabling LTI Names and Role Provisioning Services can
              improve the performance of grade passback.
            </p>

            <p>
              To enable this service, ensure that all of the following scopes are present in your LMS configuration:
            </p>

            <ul>
              <%= for scope <- Lti_1p3.Tool.Services.NRPS.required_scopes() do %>
                <li><code>{scope}</code></li>
              <% end %>
            </ul>
          </div>
        <% end %>
      </div>

      <div class="card-footer">
        <button class="btn btn-primary" phx-click="test_connection">
          Test Connection
        </button>

        <%= if !is_nil(@test_output) do %>
          <blockquote>
            <%= for line <- @test_output do %>
              {render_line(assigns, line)}
            <% end %>
          </blockquote>
        <% end %>
      </div>
    </div>
    """
  end

  def render_line(assigns, {text, :normal}) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <samp>{@text}</samp> <br />
    """
  end

  def render_line(assigns, {text, :success}) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <samp style="color: darkgreen;">{@text}</samp> <br />
    """
  end

  def render_line(assigns, {text, :failure}) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <samp style="color: darkred;">{@text}</samp> <br />
    """
  end
end
