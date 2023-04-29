defmodule Server.Connection do
  use GenServer

  @tick_rate 50

  def start_link(_) do
    options = [name: __MODULE__]
    GenServer.start_link(__MODULE__, [], options)
  end

  def init(_) do
    Process.send_after(__MODULE__, :send_state, @tick_rate)
    {:ok, []}
  end

  def handle_info({player_name, request}, state) do
    player_list = Registry.lookup(Server.PlayerRegistry, player_name)

    case Enum.empty?(player_list) do
      false ->
        [{supervisor_pid, _}] = player_list
        {:ok, connection_pid} = Server.Player.Supervisor.get_connection(supervisor_pid)
        send(connection_pid, request)

      true ->
        Server.PlayerSupervisor.add_player(player_name)
    end

    {:noreply, state}
  end

  def handle_info(:send_state, state_pid) do
    {player_names, player_states} =
      for {_, supervisor_pid, _, _} <- DynamicSupervisor.which_children(Server.PlayerSupervisor),
          reduce: {[], []} do
        {player_names, player_states} ->
          %{player_name: player_name} =
            player_state =
            Server.Player.Supervisor.get_state(supervisor_pid)
            |> elem(1)
            |> Agent.get(& &1)

          {[player_name | player_names], [player_state | player_states]}
      end

    for player_name <- player_names do
      send({Client.Connection, player_name}, {:update_state, player_states})
    end

    Process.send_after(__MODULE__, :send_state, @tick_rate)

    {:noreply, state_pid}
  end
end
