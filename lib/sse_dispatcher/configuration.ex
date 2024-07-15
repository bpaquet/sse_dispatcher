defmodule SseDispatcher.Configuration do
  use GenServer

  @signature_algorithm "RS256"

  def start_link(default) do
    GenServer.start_link(__MODULE__, default, name: __MODULE__)
  end

  def public_issuer_signers do
    GenServer.call(__MODULE__, :public_issuer_signers)
  end

  @impl true
  def init(_opts) do
    {:ok, %{public_issuer_signers: build_public_issuer_signers()}}
  end

  @impl true
  def handle_call(:public_issuer_signers, _from, state) do
    {:reply, state[:public_issuer_signers], state}
  end

  defp build_public_issuer_signers do
    Application.fetch_env!(:sse_dispatcher, :public_issuers)
    |> Enum.map(fn {issuer_name, public_key} ->
      {to_string(issuer_name), Joken.Signer.create(@signature_algorithm, %{"pem" => public_key})}
    end)
    |> Map.new()
  end
end
