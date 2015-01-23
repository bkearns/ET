defmodule ETReducersTest do
  use ExUnit.Case

  test "all?" do
    lt_four = ET.Reducers.all?(&(&1<4))
    assert ET.reduce([1,2,3], lt_four) == true
    assert ET.reduce([1,2,3,4], lt_four) == false
  end
  
  test "list reducer" do
    assert ET.reduce([1,2,3,4], ET.Reducers.list) == [1,2,3,4]
    assert ET.reduce([1,2,3,4], (ET.Transducers.take(2) |> ET.Reducers.list)) == [1,2]
  end
end
