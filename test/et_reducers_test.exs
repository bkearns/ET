defmodule ETReducersTest do
  use ExUnit.Case

  test "all?" do
    lt_four = ET.Reducers.all?(&(&1<4))
    assert ET.reduce([1,2,3], lt_four) == true
    assert ET.reduce([1,2,3,4], lt_four) == false
    assert ET.reduce([true, true], ET.Reducers.all?) == true
    assert ET.reduce([true, false, true], ET.Reducers.all?) == false
  end

  test "any?" do
    lt_two = ET.Reducers.any?(&(&1<2))
    assert ET.reduce([1,2,3], lt_two) == true
    assert ET.reduce([2,3,4], lt_two) == false
    assert ET.reduce([false, true], ET.Reducers.any?) == true
    assert ET.reduce([false, false], ET.Reducers.any?) == false
  end
  
  test "list reducer" do
    assert ET.reduce([1,2,3,4], ET.Reducers.list) == [1,2,3,4]
    assert ET.reduce([1,2,3,4], (ET.Transducers.take(2) |> ET.Reducers.list)) == [1,2]
  end
end
