defmodule Server.Player.Supervisor do
  use Supervisor, restart: :transient

  def start_link(player_name) do
    options = [name: {:via, Registry, {Server.PlayerRegistry, player_name}}]
    Supervisor.start_link(__MODULE__, player_name, options)
  end

  def get_state(pid) do
    get_child(pid, Server.Player.State)
  end

  def get_connection(pid) do
    get_child(pid, Server.Player.Connection)
  end

  def init(player_name) do
    children = [
      {Server.Player.State, player_name},
      {Server.Player.Connection, player_name}
    ]

    options = [
      strategy: :one_for_one,
      auto_shutdown: :any_significant
    ]

    Supervisor.init(children, options)
  end

  defp get_child(supervisor_pid, child_id) do
    child_pid =
      Supervisor.which_children(supervisor_pid)
      |> List.keyfind(child_id, 0)
      |> elem(1)

    {:ok, child_pid}
  end
end
