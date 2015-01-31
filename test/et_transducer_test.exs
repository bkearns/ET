defmodule ETTransducerTest do
  use ExUnit.Case, async: true

  test "compose transducer with reducer" do
    take_two_list = ET.Transducer.compose(ET.Transducers.take(2), ET.Reducers.list())
    assert ET.reduce([1,2,3,4], take_two_list) == [1,2]
  end

  test "compose two transducers" do
    take_two_inc = ET.Transducer.compose(ET.Transducers.take(2), ET.Transducers.map(fn x -> x+1 end))
    take_two_inc_list = ET.Transducer.compose(take_two_inc, ET.Reducers.list())
    assert ET.reduce([1,2,3,4], take_two_inc_list) == [2,3]
  end
end
