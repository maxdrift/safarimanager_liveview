defmodule SMWeb.SelectionPrintoutHTML do
  use SMWeb, :html
  use SMWeb.Views.FipsasLogoView

  alias SM.Teams

  embed_templates "selection_printout_html/*"
end
