defmodule Oli.Delivery.Certificates.CertificateRenderer do
  use OliWeb, :verified_routes

  @template """
  <html lang="en">
  <meta charset="UTF-8" />
  <style>
    @page {
      size: landscape;
    }

    body {
      background-color: inherit;
      margin: 0;
      padding: 0;
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
    }

    .frame-container {
      margin: 40px 60px;
      border: 1px solid #D3D3D3;
      border-radius: 0.3rem;
      padding: 22px 20px;
      background-color: white;
    }

    .outer-container {
      border: 4px solid #917e08;
      padding: 2px;
      width: 800px;
    }

    .inner-container {
      border: 2px solid #ad9e52;
      padding: 20px;
      text-align: center;
      font-family: Arial, sans-serif;
      background-color: white;
    }

    .signature {
      margin: 0;
      font-family: 'Alex Brush', 'Segoe Script', 'Brush Script MT', 'Lucida Handwriting', cursive;
      font-size: 20px;
    }
  </style>
  <body>
    <div class="frame-container">
      <div class="outer-container">
        <div class="inner-container">
          <h1 style="color:#8f7b00;font-family:'DejaVu Serif', 'Times New Roman', Times, serif;font-weight:400;font-size:50px;"><%= @certificate_type %></h1>
          <p>This certificate is presented to</p>
          <h2 style="font-size: 24px; font-weight: bold;"><%= @student_name %></h2>
          <p>on <strong><%= @completion_date %></strong> for completing</p>
          <h3 style="font-size: 22px; font-weight: bold;"><%= @course_name %></h3>
          <p style="font-style: italic;"><%= @course_description %></p>

          <div style="margin-top: 40px;">
            <div style="display: flex; justify-content: space-around;">
              <%= for {admin_name, admin_description} <- @administrators do %>
                <div>
                  <p class="signature">
                    <%= admin_name %>
                  </p>
                  <p style="margin: 0; font-size: small;"><%= admin_description %></p>
                </div>
              <% end %>
            </div>
          </div>

          <div style="margin-top: 20px; margin-bottom: 10px; display: flex; justify-content: center;">
            <%= for logo <- @logos, logo not in ["", nil] do %>
              <img src="<%= logo %>" style="max-height: 50px; margin-right: 25px; margin-left: 25px;" />
            <% end %>
          </div>
          <a href="<%= @certificate_verification_url %>" style="margin-top: 20px; font-size: small; text-decoration-line: none; color: black">Certificate ID: <%= @certificate_id %></a>
        </div>
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
      certificate_verification_url:
        url(OliWeb.Endpoint, ~p"/certificates?cert_guid=#{granted_certificate.guid}"),
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
