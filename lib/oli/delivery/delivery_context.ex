defmodule Oli.Delivery.DeliveryContext do
  @moduledoc """
  Defines and builds the DeliveryContext data required for the DeliveryContextProvider.
  """

  alias Oli.Accounts.{Author, User}
  alias Oli.Delivery.Sections

  defstruct [
    # the delivery mode module to be used for resolving in the current context
    :provider,
    :user,
    :author,
    :platform_roles,
    :context_roles
  ]

  def for_learner(%User{} = user, section_slug) do
    context_roles = Sections.get_context_roles(user, section_slug)

    %__MODULE__{
      provider: Oli.Delivery.DeliveryContext.UserProvider,
      user: user,
      platform_roles: user.platform_roles,
      context_roles: context_roles
    }
  end

  # Used in authoring preview mode to preview the student delivery view as an author
  def for_author_preview(%Author{} = author) do
    %__MODULE__{
      provider: Oli.Delivery.DeliveryContext.AuthorProvider,
      author: author,
      platform_roles: [
        Lti_1p3.Tool.PlatformRoles.get_role(:institution_student),
        Lti_1p3.Tool.PlatformRoles.get_role(:institution_learner)
      ],
      context_roles: [
        Lti_1p3.Tool.ContextRoles.get_role(:context_learner)
      ]
    }
  end

  # Used by admins who want to preview the delivery view as a student
  def for_admin_student_preview(%Author{} = author) do
    %__MODULE__{
      provider: Oli.Delivery.DeliveryContext.AuthorProvider,
      author: author,
      platform_roles: [
        Lti_1p3.Tool.PlatformRoles.get_role(:institution_student),
        Lti_1p3.Tool.PlatformRoles.get_role(:institution_learner)
      ],
      context_roles: [
        Lti_1p3.Tool.ContextRoles.get_role(:context_learner)
      ]
    }
  end
end
