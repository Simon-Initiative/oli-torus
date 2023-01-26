defmodule Oli.Cldr do
  use Cldr,
    locales: ["en"],
    default_locale: "en",
    providers: [Cldr.Number, Money, Cldr.Calendar, Cldr.DateTime]
end
