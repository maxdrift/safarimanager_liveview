defmodule SMWeb.Views.FipsasLogoView do
  @moduledoc """
  Fipsas logo SVG macro
  """

  @spec __using__(any) :: {:__block__, [], [{:@, [...], [...]} | {:def, [...], [...]}, ...]}
  defmacro __using__(_opts) do
    quote do
      @fipsas_logo_svg :safarimanager
                       |> :code.priv_dir()
                       |> Path.join(["/static", "/images", "/fipsas-logo.svg"])
                       |> File.read!()

      def fipsas_logo do
        quote do
          {:safe, unquote(@fipsas_logo_svg)}
        end
      end
    end
  end
end
