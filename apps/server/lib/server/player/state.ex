defmodule Server.Player.State do
  use Agent, restart: :transient, significant: true

  @yaw_step 1 / :math.pi()
  #@full_circle :math.tau()
  @full_circle :math.pi() * 2

  defstruct [:player_name, position: {1.1, 1.1}, yaw: 0]

  def start_link(player_name) do
    state = %Server.Player.State{player_name: player_name}
    Agent.start_link(fn -> state end)
  end

  def input(pid, action) do
    function = Function.capture(__MODULE__, action, 1)
    Agent.update(pid, function)
  end

  def move_forward(%{position: {x, z}} = state) do
    %{state | position: {x, z + 0.1}}
  end

  def move_backward(%{position: {x, z}} = state) do
    %{state | position: {x, z - 0.1}}
  end

  def move_left(%{position: {x, z}} = state) do
    %{state | position: {x - 0.1, z}}
  end

  def move_right(%{position: {x, z}} = state) do
    %{state | position: {x + 0.1, z}}
  end

  def turn_left(%{yaw: yaw} = state) do
    normalized_yaw = :math.fmod(yaw + @yaw_step, @full_circle)
    %{state | yaw: normalized_yaw}
  end

  def turn_right(%{yaw: yaw} = state) do
    normalized_yaw = :math.fmod(yaw - @yaw_step, @full_circle)
    normalized_yaw = case normalized_yaw < 0 do
      false -> normalized_yaw
      true -> @full_circle + normalized_yaw
    end
    %{state | yaw: normalized_yaw}
  end
end
