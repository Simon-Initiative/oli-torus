defmodule OliWeb.Storybook do
  use PhoenixStorybook,
    otp_app: :oli_web,
    content_path: Path.expand("storybook", __DIR__),
    # assets path are remote path, not local file-system paths
    css_path: "/assets/storybook.css",
    js_path: "/js/storybook.js",
    sandbox_class: "oli-web"
end
