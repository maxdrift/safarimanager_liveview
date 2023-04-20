if Mix.target() == :app do
  defmodule SMApp do
    use GenServer

    def start_link(arg) do
      GenServer.start_link(__MODULE__, arg, name: __MODULE__)
    end

    @impl true
    def init(_) do
      {:ok, pid} = ElixirKit.start()
      ref = Process.monitor(pid)

      ElixirKit.publish("url", SMWeb.Endpoint.access_url())

      {:ok, %{ref: ref}}
    end

    @impl true
    def handle_info({:event, "open", url}, state) do
      open(url)
      {:noreply, state}
    end

    @impl true
    def handle_info({:DOWN, ref, :process, _, :shutdown}, state) when ref == state.ref do
      SM.Config.shutdown()
      {:noreply, state}
    end

    defp open("") do
      open(SMWeb.Endpoint.access_url())
    end

    defp open("file://" <> path) do
      path
      |> SM.Utils.notebook_open_url()
      |> open()
    end

    defp open("smgr://" <> rest) do
      "https://#{rest}"
      |> SM.Utils.notebook_import_url()
      |> open()
    end

    defp open("/settings") do
      %{SMWeb.Endpoint.access_struct_url() | path: "/settings"}
      |> to_string()
      |> open()
    end

    defp open(url) do
      SM.Utils.browser_open(url)
    end
  end
end
