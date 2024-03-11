defmodule Oli.Authoring.Course.CreativeCommons do
  @cc_options %{
    none: %{
      text: "Non-CC / Copyrighted / Other",
      url: ""
    },
    cc_by: %{
      text: "CC BY: Attribution",
      url: "https://creativecommons.org/licenses/by/4.0/"
    },
    cc_by_sa: %{
      text: "CC BY-SA: Attribution-ShareAlike",
      url: "https://creativecommons.org/licenses/by-sa/4.0/"
    },
    cc_by_nd: %{
      text: "CC BY-ND: Attribution-NoDerivatives",
      url: "https://creativecommons.org/licenses/by-nd/4.0/"
    },
    cc_by_nc: %{
      text: "CC BY-NC: Attribution-NonCommercial",
      url: "https://creativecommons.org/licenses/by-nc/4.0/"
    },
    cc_by_nc_sa: %{
      text: "CC BY-NC-SA: Attribution-NonCommercial-ShareAlike",
      url: "https://creativecommons.org/licenses/by-nc-sa/4.0/"
    },
    cc_by_nc_nd: %{
      text: "CC BY-NC-ND: Attribution-NonCommercial-NoDerivatives",
      url: "https://creativecommons.org/licenses/by-nc-nd/4.0/"
    },
    custom: %{
      text: "",
      url: ""
    }
  }

  def cc_options(), do: @cc_options
end
