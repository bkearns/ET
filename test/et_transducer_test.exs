defmodule ETTransducerTest do
  use ExUnit.Case

  defmacro list_reducer do
    quote do
      fn
        :init                            -> { :cont, [[]] }
        {:fin, [acc]}                    -> { :fin, :lists.reverse(acc) }
        {:cont, input, [acc]}            -> { :cont, [[input | acc]] }
      end
    end
  end

  test "compose/2" do
    take_two_list = ET.Transducer.compose(ET.take(2), list_reducer)
    assert ET.reduce([1,2,3,4], take_two_list) == [1,2]
  end

  test "combine/2" do
    take_two_inc = ET.Transducer.combine(ET.take(2), ET.map(fn x -> x+1 end))
    take_two_inc_list = ET.Transducer.compose(take_two_inc, list_reducer)
    assert ET.reduce([1,2,3,4], take_two_inc_list) == [2,3]
  end
end
