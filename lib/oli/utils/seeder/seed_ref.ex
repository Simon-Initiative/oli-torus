defmodule Oli.Utils.Seeder.SeedRef do
  @moduledoc """
  A struct that represents a value to be pulled from the seeds.

  When an opt is provided, it can be declared as a "ref" in which case the
  value will be pulled from the seeds map.

  This allows a value to either be directly provided to a job, or pulled from a
  previously executed job in a pipe chain without having to break the pipeline.

  For example, instead of having to do this to access the created author:
  ```
    seeds =
      seeds
      |> create_author(author_tag: :author)

    seeds =
      seeds
      |> create_project(seeds.author)
  ```

  One could do this:
  ```
    seeds =
      seeds
      |> create_author(author_tag: :my_author)
      |> create_project(ref(:my_author))
  ```

  Because the call to `create_project` specifies `ref(:my_author)` for the `author` param,
  the function will fetch the value of the `:my_author` tag from the seeds map.
  """
  defstruct [:tag]

  @type t() :: %__MODULE__{
          tag: Atom.t()
        }
end
