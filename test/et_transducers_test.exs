defmodule ETTransducersTest do
  use ExUnit.Case
  
  test "ET.Transducers.map" do
    inc_list =
      ET.Transducers.map(fn input -> input + 1 end)
      |> ET.Reducers.list()
    assert ET.reduce([1,2,3], inc_list) == [2,3,4]
  end

  test "ET.Transducers.stateful" do
    take_2 = ET.Transducers.stateful(
      fn
        _input, 0 -> {:halt, 0}
        input, n  -> {:cont, input, n-1}
      end, 2)
    take_2_reducer = take_2 |> ET.Reducers.list()
    assert ET.reduce([1,2,3,4], take_2_reducer) == [1,2]
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
