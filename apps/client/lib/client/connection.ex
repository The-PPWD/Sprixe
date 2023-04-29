defmodule Client.Connection do
  use GenServer

  @server :one@Orang

  def start_link(_) do
    options = [name: __MODULE__]
    GenServer.start_link(__MODULE__, [], options)
  end

  def send_input(action) do
    GenServer.cast(__MODULE__, {:send_input, action})
  end

  def init(_) do
    {:ok, []}
  end

  def handle_cast({:send_input, action}, state) do
    case action do
      :shutdown -> send({Server.Connection, @server}, {node(), {:shutdown, []}})
      _ -> send({Server.Connection, @server}, {node(), {:move, action}})
    end

    {:noreply, state}
  end

  def handle_info({function, arguments}, state) do
    Task.start(Client.Render, function, [arguments])
    {:noreply, state}
  end
end
