if Mix.target() == :app do
  defmodule SMApp do
    use GenServer

    def start_link(arg) do
      GenServer.start_link(__MODULE__, arg, name: __MODULE__)
    end

    @impl true
    def init(_) do
      open_browser()
      ElixirKit.subscribe()
      {:ok, nil}
    end

    @impl true
    def handle_info({:open_url, "file://" <> path}, state) do
      path
      |> SM.Utils.notebook_open_url()
      |> open_browser()

      {:noreply, state}
    end

    def handle_info({:open_browser, ""}, state) do
      open_browser()
      {:noreply, state}
    end

    defp open_browser(url \\ SMWeb.Endpoint.access_url()) do
      SM.Utils.browser_open(url)
    end
  end
end
