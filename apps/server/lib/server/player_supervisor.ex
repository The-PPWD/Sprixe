defmodule Server.PlayerSupervisor do
  use DynamicSupervisor

  def start_link(_) do
    options = [name: __MODULE__]
    DynamicSupervisor.start_link(__MODULE__, [], options)
  end

  def add_player(player_name) do
    child_spec =
      Supervisor.child_spec(
        {Server.Player.Supervisor, player_name},
        id: player_name
      )

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def remove_player(player_name) do
    [{pid, _}] = Registry.lookup(Server.PlayerRegistry, player_name)
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def init(_) do
    options = [strategy: :one_for_one]
    DynamicSupervisor.init(options)
  end
end
