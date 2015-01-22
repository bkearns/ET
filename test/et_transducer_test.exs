defmodule ETTransducerTest do
  use ExUnit.Case

  test "compose/2" do
    take_two_list = ET.Transducer.compose(ET.take(2), ET.Reducers.list())
    assert ET.reduce([1,2,3,4], take_two_list) == [1,2]
  end

  test "combine/2" do
    take_two_inc = ET.Transducer.combine(ET.take(2), ET.map(fn x -> x+1 end))
    take_two_inc_list = ET.Transducer.compose(take_two_inc, ET.Reducers.list())
    assert ET.reduce([1,2,3,4], take_two_inc_list) == [2,3]
  end
end
