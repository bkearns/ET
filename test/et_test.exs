defmodule ETTest do
  use ExUnit.Case

  test "ET.reduce" do
    inc_reducer = ET.map(&(&1+1))
      |> ET.Reducers.list()

    assert ET.reduce([1,2,3], inc_reducer) == [2,3,4]
  end

  test "ET.map" do
    inc_list =
      ET.map(fn input -> input + 1 end)
      |> ET.Reducers.list()
    assert ET.reduce([1,2,3], inc_list) == [2,3,4]
  end

  test "ET.stateful" do
    take_2 = ET.stateful(
      fn
        _input, 0 -> {:halt, 0}
        input, n  -> {:cont, input, n-1}
      end, 2)
    take_2_reducer = take_2 |> ET.Reducers.list()
    assert ET.reduce([1,2,3,4], take_2_reducer) == [1,2]
  end

  test "ET.take" do
    take_three = ET.take(3) |> ET.Reducers.list()
    assert ET.reduce([1,2,3,4], take_three) == [1,2,3]
  end
  
  test "ET.zip" do
    zip_reducer =
      ET.zip
      |> ET.map(fn input -> input + 1 end)
      |> ET.Reducers.list()
    assert ET.reduce([[1,2,3,4], [8, 9]], zip_reducer) ==
           [2, 9, 3, 10, 4, 5]
  end
  
  test "ET.zip properly terminates early" do
    zip_two =
      ET.zip
      |> ET.take(2)
      |> ET.Reducers.list()

    assert ET.reduce([[1,2],[3,4],[5,6]], zip_two) == [1,3]
  end
end
