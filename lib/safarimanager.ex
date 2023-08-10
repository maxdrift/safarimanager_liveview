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

      alias __MODULE__

      @primary_key {:id, Ecto.UUID, autogenerate: true}
      @foreign_key_type Ecto.UUID
      @timestamps_opts [type: :utc_datetime_usec]
      @type t :: %__MODULE__{}
    end
  end

  def context do
    quote do
      import Ecto.Query

      alias Ecto.Multi
      alias SM.Repo

      require Logger

      @like_fragment if SM.Repo.__adapter__() == Ecto.Adapters.Postgres,
                       do: "? ILIKE ?",
                       else: "? LIKE ?"

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

      defp notify_subscribers(result, event, opts \\ [])

      defp notify_subscribers({:ok, result}, event, opts) when is_struct(result) do
        id_key = Keyword.get(opts, :id_key, :id)
        :ok = Phoenix.PubSub.broadcast(SM.PubSub, @topic, {__MODULE__, event, result})
        id = Map.get(result, id_key)

        :ok =
          Phoenix.PubSub.broadcast(
            SM.PubSub,
            @topic <> "#{id}",
            {__MODULE__, event, result}
          )

        {:ok, result}
      end

      defp notify_subscribers({:ok, result}, event, _opts) do
        :ok = Phoenix.PubSub.broadcast(SM.PubSub, @topic, {__MODULE__, event, result})

        {:ok, result}
      end

      defp notify_subscribers({:error, reason}, _event, _opts), do: {:error, reason}
      defp notify_subscribers(:error, _event, _opts), do: :error
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
