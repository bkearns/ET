defmodule ETTest do
  use ExUnit.Case, async: true

  test "ET.reduce" do
    inc_reducer = ET.Transducers.map(&(&1+1))
      |> ET.Reducers.list()

    assert ET.reduce([1,2,3], inc_reducer) == [2,3,4]
  end

  test "ET.reduce_elements" do
    list_reducer = ET.Reducers.list
    assert {:empty, {^list_reducer, {:cont, [[2,1]]}}} =
      ET.reduce_elements([1,2], {list_reducer, {:cont, [[]]}})

    take_one_list_r = ET.Transducers.take(1) |> ET.Reducers.list
    assert {[2], {^take_one_list_r, {:done, [0,[1]]}}} =
      ET.reduce_elements([1,2], {take_one_list_r, {:cont, [0,[]]}})
  end

  test "ET.reduce_step" do
    list_reducer = ET.Reducers.list
    assert ET.reduce_step([1,2], {list_reducer, {:cont, [[]]}}) ==
           {[2], {list_reducer, {:cont, [[1]]}}}
    assert ET.reduce_step([], {list_reducer, {:cont, [[1]]}}) ==
           {:empty, {list_reducer, {:cont, [[1]]}}}
  end
end
