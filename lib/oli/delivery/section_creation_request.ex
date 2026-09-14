defmodule Oli.Delivery.SectionCreationRequest do
  @moduledoc """
  A single command describing one section creation.

  Section creation has accumulated positional arguments (changeset, source,
  user, section specification) and course copy adds another - the selected copy
  groups. Passing a struct keeps that from continuing, and gives the copy
  options one place to live on the way from the wizard to the domain rather than
  being threaded through LiveView assigns.

  ## Fields

    * `:changeset` - the destination section changeset built by the wizard.
    * `:source` - the raw source identifier submitted by the client, e.g.
      `"section:42"`. It is resolved and authorized by
      `Oli.Delivery.Sections.SourceResolution`, never trusted as given.
    * `:user` - the delivery user creating the section, if any. `nil` for
      admin-initiated creation, which enrolls no one.
    * `:author` - the authoring account, used for administrator authorization.
    * `:section_spec` - LTI or direct-delivery specification.
    * `:copy_options` - `Oli.Delivery.Sections.CopyOptions` for a
      previous-section source. Ignored by every other source type.
  """

  alias Oli.Delivery.Sections.CopyOptions

  @type t :: %__MODULE__{
          changeset: Ecto.Changeset.t() | nil,
          source: String.t() | nil,
          user: Oli.Accounts.User.t() | nil,
          author: Oli.Accounts.Author.t() | nil,
          section_spec: term(),
          copy_options: CopyOptions.t() | nil
        }

  defstruct changeset: nil,
            source: nil,
            user: nil,
            author: nil,
            section_spec: nil,
            copy_options: nil
end
