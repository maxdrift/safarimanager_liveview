defmodule SM do
  @moduledoc """
  SM keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  # credo:disable-for-this-file Credo.Check.Readability.Specs

  def schema do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @timestamps_opts [type: :utc_datetime_usec]
      @type t :: %__MODULE__{}
    end
  end

  def context do
    quote do
      import Ecto.Query

      alias SM.Repo

      # Phoenix PubSub subscription

      @topic inspect(__MODULE__)

      @spec subscribe() :: :ok | {:error, {:already_registered, pid()}}
      def subscribe do
        Phoenix.PubSub.subscribe(SM.PubSub, @topic)
      end

      @spec subscribe(String.t()) :: :ok | {:error, {:already_registered, pid()}}
      def subscribe(id) do
        Phoenix.PubSub.subscribe(SM.PubSub, @topic <> "#{id}")
      end

      defp notify_subscribers({:ok, result}, event) when is_struct(result) do
        :ok = Phoenix.PubSub.broadcast(SM.PubSub, @topic, {__MODULE__, event, result})

        :ok =
          Phoenix.PubSub.broadcast(
            SM.PubSub,
            @topic <> "#{result.id}",
            {__MODULE__, event, result}
          )

        {:ok, result}
      end

      defp notify_subscribers({:ok, result}, event) do
        :ok = Phoenix.PubSub.broadcast(SM.PubSub, @topic, {__MODULE__, event, result})

        {:ok, result}
      end

      defp notify_subscribers({:error, reason}, _event), do: {:error, reason}
      defp notify_subscribers(:error, _event), do: :error
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
