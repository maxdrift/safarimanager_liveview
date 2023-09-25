defmodule SMWeb.SlidesPrintoutHTML do
  use SMWeb, :html
  use SMWeb.Views.FipsasLogoView

  alias SM.Teams

  embed_templates "slides_printout_html/*"
end
