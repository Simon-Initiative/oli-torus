defmodule Oli.Delivery.Sections.Certificates.EmailTemplates do
  @moduledoc """
  This module contains the email templates for the certificates email notifications.
  """

  use OliWeb, :html

  attr :student_name, :string, default: "[Student]"
  attr :platform_name, :string, default: "[Platform Name]"
  attr :course_name, :string, default: "[Course Name]"
  attr :certificate_link, :string, default: "#"

  def student_approval(assigns) do
    ~H"""
    <p class="text-[#373a44]">
      Dear <%= @student_name %>, <br />
      <br /> Congratulations! You have earned a Certificate of Completion for <%= @course_name %>.
      <.link href={@certificate_link} class="text-[#0062f2]">
        Access you certificate here
      </.link>
      or navigate to your certificate progress on your course home page. <br />
      <br /> Steps to upload this certificate to LinkedIn:<br />
      1. Click the “Me” icon at the top of your LinkedIn homepage, then View Profile.<br />
      2. Click Add profile section in the introduction section.<br />
      3. Click Recommended dropdown, then Add licenses & certifications.<br />
      4. In the Add license or certification pop-up window that appears, enter your information into the fields provided.<br />
      5. A list displaying companies will appear as you type in the Issuing organization field. Be sure to select the correct authority from the menu so their logo appears next to the certification on your profile.<br />
      6. Click Save. <br />
      <br />
      If you have any questions or need further assistance, feel free to contact our support team.
      <br />
      <br /> Best regards, <br /> <%= @platform_name %> Team
    </p>
    """
  end

  attr :student_name, :string, default: "[Student]"
  attr :platform_name, :string, default: "[Platform Name]"
  attr :course_name, :string, default: "[Course Name]"
  attr :instructor_email, :string, default: "[instructor email]"

  def student_denial(assigns) do
    ~H"""
    <p class="text-[#373a44]">
      Dear <%= @student_name %>, <br />
      <br /> Thank you for completing the <%= @course_name %> on <%= @platform_name %>. <br />
      <br />
      After reviewing your progress, we regret to inform you that you did not meet the requirements necessary to earn a certificate for this course. Please note that the certificate eligibility is based on the completion of all requirements and achieving the minimum score threshold.
      <br />
      <br />
      If you have any questions or would like feedback on your progress, please contact your instructor at <%= @instructor_email %>.
      <br />
      <br /> Thank you for your participation. <br />
      <br /> Best regards, <br /> <%= @platform_name %> Team
    </p>
    """
  end
end
