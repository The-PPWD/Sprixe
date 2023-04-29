defmodule Server.Player.Connection do
  use GenServer

  def start_link(player_name) do
    GenServer.start_link(__MODULE__, player_name)
  end

  def init(player_name) do
    {:ok, [], {:continue, player_name}}
  end

  def handle_continue(player_name, _) do
    [{supervisor_pid, _}] = Registry.lookup(Server.PlayerRegistry, player_name)
    {:ok, state_pid} = Server.Player.Supervisor.get_state(supervisor_pid)
    {:noreply, state_pid}
  end

  def handle_info({function, arguments}, state_pid) do
    Task.start(Server.Player.State, function, [state_pid, arguments])
    {:noreply, state_pid}
  end
end
