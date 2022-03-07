defmodule SMWeb.HomeController do
  use SMWeb, :controller

  @spec new(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def new(conn, _params) do
    redirect(conn, to: "/organize/new")
  end
end
