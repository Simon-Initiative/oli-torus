defmodule Oli.Delivery.Certificates.CertificateRenderer do
  @template """
  <html lang="en">
  <meta charset="UTF-8" />
  <style>
    @page {
      size: landscape;
    }

    body {
      background-color: white;
      margin: 0;
      padding: 0;
    }

    .outer-container {
      border: 4px solid #917e08;
      padding: 2px;
      width: 800px;
      margin: 40px auto;
    }

    .inner-container {
      border: 2px solid #ad9e52;
      padding: 20px;
      text-align: center;
      font-family: Arial, sans-serif;
      background-color: white;
    }
  </style>
  <body>
    <div class="outer-container">
      <div class="inner-container">
        <h1 style="color: #8f7b00; font-family: 'Times New Roman', Times, serif; font-weight: normal; font-size: 50px;"><%= @certificate_type %></h1>

        <p>This certificate is presented to</p>
        <h2 style="font-size: 24px; font-weight: bold;"><%= @student_name %></h2>
        <p>on <strong><%= @completion_date %></strong> for completing</p>
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
            <img src="<%= logo %>" style="max-height: 50px; margin-right: 50px;" />
          <% end %>
        </div>

        <p style="margin-top: 20px; font-size: small;">Certificate ID: <%= @certificate_id %></p>
      </div>
    </div>
  </body>
  </html>
  """

  alias Oli.Delivery.Sections.GrantedCertificate
  alias Oli.Repo

  def render(%GrantedCertificate{} = gc) do
    granted_certificate = Repo.preload(gc, [:certificate, :user])

    certificate_type =
      if granted_certificate.with_distinction,
        do: "Certificate with Distinction",
        else: "Certificate of Completion"

    admin_fields =
      Map.take(granted_certificate.certificate, [
        :admin_name1,
        :admin_title1,
        :admin_name2,
        :admin_title2,
        :admin_name3,
        :admin_title3
      ])

    admins =
      [
        {admin_fields.admin_name1, admin_fields.admin_title1},
        {admin_fields.admin_name2, admin_fields.admin_title2},
        {admin_fields.admin_name3, admin_fields.admin_title3}
      ]
      |> Enum.reject(fn {name, _} -> name == "" || !name end)

    logos =
      [
        granted_certificate.certificate.logo1,
        granted_certificate.certificate.logo2,
        granted_certificate.certificate.logo3
      ]
      |> Enum.reject(fn logo -> logo == "" || !logo end)

    attrs = %{
      certificate_type: certificate_type,
      student_name: granted_certificate.user.name,
      completion_date:
        granted_certificate.issued_at |> DateTime.to_date() |> Calendar.strftime("%B %d, %Y"),
      certificate_id: granted_certificate.guid,
      course_name: granted_certificate.certificate.title,
      course_description: granted_certificate.certificate.description,
      administrators: admins,
      logos: logos
    }

    render(attrs)
  end

  def render(assigns) do
    EEx.eval_string(@template, assigns: assigns, engine: Phoenix.LiveView.HTMLEngine)
  end
end
