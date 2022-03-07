defmodule SMWeb.HomeController do
  use SMWeb, :controller

  def new(conn, _params) do
    redirect(conn, to: "/organize/new")
  end
end
