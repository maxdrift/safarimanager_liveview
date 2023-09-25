defmodule SMWeb.ResultsPrintoutHTML do
  use SMWeb, :html
  use SMWeb.Views.FipsasLogoView

  alias SM.Teams

  embed_templates "results_printout_html/*"
end
