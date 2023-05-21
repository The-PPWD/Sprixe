defmodule Server.Connection do
  use GenServer

  @tick_rate 1000

  @map_state [
    1, 1, 1, 1,
    1, 0, 0, 1,
    1, 0, 0, 1,
    1, 1, 1, 1,
  ]

  def start_link(_) do
    options = [name: __MODULE__]
    GenServer.start_link(__MODULE__, [], options)
  end

  def init(_) do
    queue_tick()
    {:ok, []}
  end

  def handle_info({:connect, player_name}, state) do
    Server.PlayerSupervisor.add_player(player_name)
    send({Client.Connection, player_name}, {:map, @map_state})
    {:noreply, state}
  end

  def handle_info({:input, player_name, action}, state) do
    [{supervisor_pid, _}] = Registry.lookup(Server.PlayerRegistry, player_name)
    connection_pid = Server.Player.Supervisor.get_connection(supervisor_pid)

    send(connection_pid, {:input, action})

    {:noreply, state}
  end

  def handle_info({:disconnect, player_name}, state) do
    Server.PlayerSupervisor.remove_player(player_name)
    {:noreply, state}
  end

  def handle_info(:tick, state_pid) do
    {player_names, player_states} =
      for {_, supervisor_pid, _, _} <- DynamicSupervisor.which_children(Server.PlayerSupervisor),
          reduce: {[], []} do
        {player_names, player_states} ->
          %{player_name: player_name} =
            player_state =
            Server.Player.Supervisor.get_state(supervisor_pid)
            |> Agent.get(& &1)

          {[player_name | player_names], [player_state | player_states]}
      end

    for player_name <- player_names do
      send({Client.Connection, player_name}, {:tick, player_states})
    end

    queue_tick()

    {:noreply, state_pid}
  end

  # TODO: Looping could be handled in another process? Preventing handle_info from recalling
  defp queue_tick(), do: Process.send_after(__MODULE__, :tick, @tick_rate)
end
