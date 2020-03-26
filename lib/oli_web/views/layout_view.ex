defmodule OliWeb.LayoutView do
  use OliWeb, :view

  import OliWeb.DeliveryView, only: [user_role: 1, user_role_text: 1, user_role_color: 1, account_linked?: 1]
  import Oli.Accounts, only: [user_signed_in?: 1, author_signed_in?: 1]
end
