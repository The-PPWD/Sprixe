defmodule Client.Connection do
  use GenServer

  require Logger

  @server :one@Orang

  def start_link(_) do
    options = [name: __MODULE__]
    GenServer.start_link(__MODULE__, [], options)
  end

  def connect() do
    GenServer.cast(__MODULE__, {:connect, node()})
  end

  def send_input(action) do
    GenServer.cast(__MODULE__, {:send_input, node(), action})
  end

  def disconnect() do
    GenServer.cast(__MODULE__, {:disconnect, node()})
  end

  def init(_) do
    connect()
    {:ok, []}
  end

  def handle_cast({:connect, player_name}, state) do
    Logger.info("Connecting to server #{inspect(@server)}.")
    send({Server.Connection, @server}, {:connect, player_name})
    {:noreply, state}
  end

  def handle_cast({:send_input, player_name, action}, state) do
    Logger.info("Sending action #{inspect(action)} to server #{inspect(@server)}.")
    send({Server.Connection, @server}, {:input, player_name, action})
    {:noreply, state}
  end

  def handle_cast({:disconnect, player_name}, state) do
    Logger.info("Disconnecting from server #{inspect(@server)}.")
    send({Server.Connection, @server}, {:disconnect, player_name})
    {:noreply, state}
  end

  def handle_info({:map, map_state}, state) do
    Logger.info("Received map #{inspect(map_state)} from server #{inspect(@server)}.")
    Task.start(Client.Render, :map, [map_state])
    {:noreply, state}
  end

  def handle_info({:tick, player_states}, state) do
    Logger.info("Received player states #{inspect(player_states)} from server #{inspect(@server)}.")
    Task.start(Client.Render, :tick, [player_states])
    {:noreply, state}
  end
end
