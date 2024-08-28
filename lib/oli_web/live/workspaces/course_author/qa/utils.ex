defmodule OliWeb.Workspaces.CourseAuthor.Qa.Utils do
  use Phoenix.HTML

  def warning_icon(type) do
    case type do
      "accessibility" -> {"fa-brands fa-accessible-icon", "#ffd868"}
      "content" -> {"fa-regular fa-image", "#ffa351ff"}
      "pedagogy" -> {"fa-solid fa-person-chalkboard", "#ffbe7bff"}
      _ -> {"fa-solid fa-triangle-exclamation", "#eed971ff"}
    end
    |> icon()
    |> raw()
  end

  def icon({name, color}) do
    ~s|<i style="color: #{color}" class="#{name}"></i>|
  end

  def warning_selected?(selected, warning) do
    case selected == warning do
      true -> " active"
      false -> ""
    end
  end

  def explanatory_text(subtype, context \\ %{}) do
    case subtype do
      "missing alt text" ->
        """
        <p>
          Providing alternative text for non-text content such as images and videos enables users
          with visual impairments to understand the reason and context for the provided content.
        </p>
        <p>
          For more information on the importance of providing contextual alternative text to non-text content, see the
          <a href="https://webaim.org/techniques/alttext/#basics" target="_blank">alt text accessibility guide</a> on WebAIM.org.
        </p>
        """

      "nondescriptive link text" ->
        """
        <p>
          Links are more useful to users when they are provided with descriptive context instead of a raw URL or
          generic text such as "click here" or "learn more."
        </p>
        <p>
          For more information on the importance of providing textual context for links, see the
          <a href="https://webaim.org/techniques/hypertext/link_text#text" target="_blank">Link text accessibility guide</a> on WebAIM.org.
        </p>
        """

      "broken remote resource" ->
        """
        <p>
          A link or an image hosted on another website was not able to be found. This might be a temporary problem, or it could
          mean the link or image path is broken and needs to be updated.
        </p>
        """

      "no attached objectives" ->
        """
        <p>
          One of the Open Learning Initiative's core features is providing analytics on course content to identify
          areas in the course that can be improved. This only works when pages and activities have objectives attached to them.
        </p>
        <p>
          You can publish a course without linking objectives to course content, but no analytics will be generated for this content.
        </p>
        <p>
          For more information on the importance of attaching learning objectives to pages and activities, see the
          <a class="external" href="https://www.cmu.edu/teaching/designteach/design/learningobjectives.html" target="_blank">guide on learning objectives</a> from the CMU Eberly Center.
        </p>
        """

      "no attached activities" ->
        case context[:graded] do
          true ->
            """
            <p>
              This graded page does not have any attached activities. In order to provide a grade, the page must have at least one activity.
            </p>
            """

          _ ->
            """
            <p>
              This page does not provide any practice opportunities in the form of activities for the material students may have learned on the page.
              That's fine for introductory or conclusory pages, but pages with learning content should generally provide practice opportunities.
            </p>
            <p>
              For more information on the importance of providing practice opportunities in pages, see the
              <a class="external" href="https://www.cmu.edu/teaching/designteach/design/assessments.html" target="_blank">guide on assessments</a> from the CMU Eberly Center.
            </p>
            """
        end

      _ ->
        ""
    end
    |> raw()
  end

  def action_item(subtype, context \\ %{}) do
    case subtype do
      "missing alt text" ->
        """
        <p>Add alternative text to this content</p>
        """

      "nondescriptive link text" ->
        """
        <p>Provide more descriptive text for this link</p>
        """

      "broken remote resource" ->
        """
        <p>Check to make sure this link or image is not broken</p>
        """

      "no attached objectives" ->
        """
        <p>Attach a learning objective to this page or activity</p>
        """

      "no attached activities" ->
        case context[:graded] do
          true ->
            """
            <p>Add an activity to this page or change it to an ungraded page</p>
            """

          _ ->
            """
            <p>Consider adding an activity to this page if it provides learning content</p>
            """
        end

      _ ->
        """
        <p>This content has an issue</p>
        """
    end
    |> raw()
  end
end
