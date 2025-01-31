defmodule Oli.Delivery.Certificates.CertificateRenderer do
  @template """
  <html lang="en">
  <meta charset="UTF-8" />
  <style>
    @page {
      size: landscape;
    }
  </style>
  <div style="border: 1px solid #ccc; padding: 20px; width: 800px; text-align: center; font-family: Arial, sans-serif;">
    <h1 style="color: gold;"><%= @certificate_type %></h1>
    <p>This certificate is presented to</p>
    <h2 style="font-size: 24px; font-weight: bold;"><%= @student_name %></h2>
    <p>on <%= @completion_date %> for completing</p>
    <h3 style="font-size: 22px; font-weight: bold;"><%= @course_name %></h3>
    <p style="font-style: italic;"><%= @course_description %></p>

    <div style="margin-top: 40px;">
      <div style="display: flex; justify-content: space-around;">
        <%= for {admin_name, admin_description} <- @administrators do %>
          <div>
            <p style="margin: 0; font-weight: bold; font-family: 'Alex Brush', cursive; font-size: 20px;">
              <%= admin_name %>
            </p>
            <p style="margin: 0; font-size: small;"><%= admin_description %></p>
          </div>
        <% end %>
      </div>
    </div>

    <div style="margin-top: 20px; display: flex; justify-content: center;">
      <%= for logo <- @logos do %>
        <img src="<%= logo %>" style="max-height: 50px; margin-right: 10px;" />
      <% end %>
    </div>

    <p style="margin-top: 20px; font-size: small;">Certificate ID: <%= @certificate_id %></p>
  </div>
  </html>

  """

  def render(assigns) do
    EEx.eval_string(@template, assigns: assigns, engine: Phoenix.LiveView.HTMLEngine)
  end
end
