defmodule ETTransducersTest do
  use ExUnit.Case

  test "ET.Transducers.ensure" do
    ensure_list = ET.Transducers.ensure(2)
                  |> ET.Transducers.take(1)
                  |> ET.Reducers.list
    coll = [1,2,3]
    {:cont, state} = ensure_list.(:init)
    assert {{:cont, state},  coll} = ET.reduce_step(coll, state, ensure_list)
    assert {{:halt, state}, _coll} = ET.reduce_step(coll, state, ensure_list)
    assert {:fin, [1]} = ensure_list.({:fin, state})

    
  end
  
  test "ET.Transducers.map" do
    inc_list =
      ET.Transducers.map(fn input -> input + 1 end)
      |> ET.Reducers.list()
    assert ET.reduce([1,2,3], inc_list) == [2,3,4]
  end

  test "ET.Transducers.take" do
    take_three = ET.Transducers.take(3) |> ET.Reducers.list()
    assert ET.reduce([1,2,3,4], take_three) == [1,2,3]
  end
  
  test "ET.Transducers.zip" do
    zip_reducer =
      ET.Transducers.zip
      |> ET.Reducers.list()
    assert ET.reduce([[1,2,3,4], [8, 9]], zip_reducer) ==
           [1, 8, 2, 9, 3, 4]
  end
  
  test "ET.Transducers.zip properly terminates early" do
    zip_two =
      ET.Transducers.zip
      |> ET.Transducers.take(2)
      |> ET.Reducers.list()

    assert ET.reduce([[1,2],[3,4],[5,6]], zip_two) == [1,3]
  end
end
