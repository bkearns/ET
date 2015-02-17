defmodule ETTest do
  use ExUnit.Case, async: true

  test "ET.reduce" do
    inc_reducer = ET.Transducers.map(&(&1+1))
      |> ET.Reducers.list()

    assert ET.reduce([1,2,3], inc_reducer) == [2,3,4]
  end

  test "ET.reduce_elements" do
    assert {:empty, [[2,1]], []} =
      ET.reduce_elements([1,2], {:cont, [[]]}, ET.Reducers.list())

    assert {:done, [0,[1]], [2]} =
      ET.reduce_elements([1,2], {:cont, [0,[]]},
        (ET.Transducers.take(1) |> ET.Reducers.list))
  end

  test "ET.reduce_step" do
    assert ET.reduce_step([1,2], [[]], ET.Reducers.list()) == {:cont, [[1]], [2]}
    assert ET.reduce_step([], [[1]], ET.Reducers.list()) == {:empty, [[1]], []}
  end
end
