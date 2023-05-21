defmodule Client.Render do
  use GenServer

  require Logger

  defstruct [:map_state, :local_player_state, :other_player_states, frame_count: 0]

  @field_of_view :math.pi() / 2
  @half_field_of_view @field_of_view / 2

  def start_link(_) do
    options = [name: __MODULE__]
    GenServer.start_link(__MODULE__, [], options)
  end

  def map(map_state) do
    GenServer.cast(__MODULE__, {:map, map_state})
  end

  def tick(player_states) do
    GenServer.cast(__MODULE__, {:tick, player_states})
  end

  def init(_) do
    {:ok, %Client.Render{}}
  end

  def handle_cast({:map, new_map_state}, %{map_state: old_map_state} = state) do
    Logger.info("Updating map from #{inspect(old_map_state)} to #{inspect(new_map_state)}.")
    new_state = %{state | map_state: new_map_state}
    {:noreply, new_state}
  end

  def handle_cast({:tick, new_player_states}, %{local_player_state: old_local_player_state, other_player_states: old_other_player_states, frame_count: frame_count} = state) do
    new_local_player_state = Enum.find(new_player_states, fn %{player_name: player_name} -> player_name === node() end)
    Logger.info("Updating local player state from #{inspect(old_local_player_state)} to #{inspect(new_local_player_state)}.")

    new_other_player_states = List.delete(new_player_states, new_local_player_state)
    Logger.info("Updating other player states from #{inspect(old_other_player_states)} to #{inspect(new_other_player_states)}.")

    new_state = %{state | local_player_state: new_local_player_state, other_player_states: new_other_player_states, frame_count: frame_count + 1}
    render(new_state)
    {:noreply, new_state}
  end

  defp render(%{frame_count: frame_count} = state) do
#    local_player_state =
#      Enum.find(player_states, fn %{player_name: player_name} -> player_name === node() end)

    ExNcurses.clear()

    Logger.metadata(frame_count: frame_count)

#    render_map(local_player_state, map_state)
    render_map(state)

    #    other_players_states = List.delete(player_states, local_player_state)
    #    render_players(local_player_state, other_players_states)
  end

  def render_map(%{local_player_state: %{yaw: yaw}} = state) do
    # can be optimized by taking first and last and dividing by cols?
    angle_step = @field_of_view / ExNcurses.cols()
    first_angle = yaw - @half_field_of_view + angle_step
    last_angle = yaw + @half_field_of_view - angle_step

    angles = Stream.iterate(first_angle, &(&1 + angle_step)) |> Enum.take_while(&(&1 <= last_angle))
    columns = Stream.iterate(0, &(&1 + 1)) |> Enum.take_while(&(&1 <= length(angles)))

    Enum.zip(angles, columns) |> Enum.each(&render_screen_column(&1, state))

    ExNcurses.refresh()
  end

#  def render_map(%{yaw: player_yaw} = player_state, map_state) do
#    Logger.info("Rendering map #{inspect(map_state)} from player #{inspect(player_state)}.")
#
#    # can be optimized by taking first and last and dividing by cols?
#    screen_column_count = ExNcurses.cols()
#    screen_column_angle_step = @field_of_view / screen_column_count
#    first_screen_column_angle = player_yaw - @half_field_of_view + screen_column_angle_step
#    last_screen_column_angle = player_yaw + @half_field_of_view - screen_column_angle_step
#
#    #screen_column_angles = first_screen_column_angle..last_screen_column_angle//screen_column_angle_step
#
#    screen_column_angles = Stream.iterate(first_screen_column_angle, &(&1 + screen_column_angle_step))
#      |> Enum.take_while(&(&1 <= last_screen_column_angle))
#
#    Logger.debug("screen column angles #{inspect(screen_column_angles)}.")
#
#    #screen_columns = 0..length(screen_column_angles)
#
#    screen_columns = Stream.iterate(0, &(&1 + 1)) |> Enum.take_while(&(&1 <= length(screen_column_angles)))
#
#    Logger.debug("screen columns #{inspect(screen_columns)}.")
#
#    Enum.zip(screen_column_angles, screen_columns) |> Enum.each(&render_screen_column(&1, player_state, map_state))
#
#    ExNcurses.refresh()
#  end

  def render_screen_column({angle, column}, %{local_player_state: %{x: player_x, z: player_z}} = state) do
    ray_x = :math.cos(angle)
    ray_z = :math.sin(angle)

    Logger.debug("Ray position (x: #{ray_x}, z: #{ray_z}).")

    {x_direction, player_partial_x} =
      case ray_x < player_x do
        false -> {:east, trunc(player_x) - player_x}
        true -> {:west, 1 - (player_x - trunc(player_x))}
      end

    Logger.debug("X direction #{x_direction}.")
    Logger.debug("Player partial x #{player_partial_x}.")

    {z_direction, player_partial_z} =
      case ray_z < player_z do
        false -> {:north, 1 - (player_z - trunc(player_z))}
        true -> {:south, trunc(player_z) - player_z}
      end

    Logger.debug("Z direction #{z_direction}.")
    Logger.debug("Player partial z #{player_partial_z}.")

    inverse_slope = ray_z / ray_x
    slope = ray_x / ray_z

    Logger.debug("Slope #{slope}.")
    Logger.debug("Inverse slope #{inverse_slope}.")

    ray_growth_per_x = (1 + :math.pow(inverse_slope, 2)) |> :math.sqrt()
    ray_growth_per_z = (1 + :math.pow(slope, 2)) |> :math.sqrt()

    Logger.debug("Ray growth per x #{ray_growth_per_x}.")
    Logger.debug("Ray growth per z #{ray_growth_per_z}.")

    collision_1 =
      cast_ray({ray_x, ray_z}, x_direction, ray_growth_per_x, player_partial_x, state)

    Logger.debug("Collision 1 #{inspect(collision_1)}.")

    collision_2 =
      cast_ray({ray_x, ray_z}, z_direction, ray_growth_per_z, player_partial_z, state)

    Logger.debug("Collision 2 #{inspect(collision_2)}.")

    {collision_x, collision_z} = Enum.filter([collision_1, collision_2], &(&1 !== nil)) |> Enum.min()

    x_distance = collision_x - player_x
    z_distance = collision_z - player_z

    Logger.debug("Distance (x: #{x_distance}, z: #{z_distance}).")

    distance = (:math.pow(x_distance, 2) + :math.pow(z_distance, 2)) |> :math.sqrt() |> ceil()

    Logger.debug("Distance #{distance}.")

    screen_height = ExNcurses.lines()

    # completely arbitrary
    column_height = abs(distance)

    column_offset = round((screen_height - column_height) / 2)

    column_offset..(column_height + column_offset) |> Enum.each(&ExNcurses.mvaddstr(&1, column, "*"))
  end

  def cast_ray({x, z}, direction, ray_growth_scalar, player_partial, state) do
    {x, z} = case direction do
      :north ->
        {x + ray_growth_scalar * (player_partial || 1),
        z + (player_partial || 1)}

      :south ->
        {x + ray_growth_scalar * (player_partial || 1),
        z + (player_partial || -1)}

      :west ->
        {x + (player_partial || -1),
        z + ray_growth_scalar * (player_partial || 1)}

      :east ->
        {x + (player_partial || 1),
        z + ray_growth_scalar * (player_partial || 1)}
    end

    Logger.debug("Casted ray (x: #{x}, z: #{z}).")

    case hit_wall({x, z}, state) do
      false -> cast_ray({x, z}, direction, ray_growth_scalar, nil, state)
      true -> {x, z}
      nil -> nil
    end
  end

  def hit_wall({x, z}, %{map_state: map_state} = state) do
    index = map_position_to_index({x, z}, state)

    Logger.debug("Map index #{index}.")

    case index === nil do
      false -> Enum.at(map_state, index) === 1
      true -> nil
    end
  end

  # maps must be square and a minimum of 9 in length
  def map_position_to_index({x, z}, %{map_state: map_state}) do
    map_state_length = length(map_state)

    # trunc() because :math.sqrt() returns a float
    map_width = map_state_length |> :math.sqrt() |> trunc()
    index = map_width * floor(z) + floor(x)

    case index < map_state_length do
      false -> nil
      true -> index
    end
  end
end
