defmodule ETTest do
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

  test "ET.compose/2" do
    inc_transducer = 
      fn reducer ->
        fn
          :init                 -> reducer.(:init)
          {:fin, state}         -> reducer.({:fin, state})
          {:cont, input, state} -> reducer.({:cont, input + 1, state})
         end
       end

    inc_trans = ET.compose([inc_transducer], list_reducer)
     inc_tests(inc_trans, [])
  end

  test "ET.map/1" do
    ET.map(fn input -> input + 1 end)
    |> ET.compose(list_reducer)
    |> inc_tests([])
  end

  defp inc_tests(inc_trans, state) do
    assert inc_trans.(:init)              == {:cont, [[]]}
    assert inc_trans.({:cont, 0, [[2]]})  == {:cont, [[1, 2]]}
    assert inc_trans.({:fin, [[2,1]]})    == {:fin, [1, 2]} 
  end

  test "ET.reduce/2" do
    inc_trans = ET.map(&(&1+1))
      |> ET.compose(list_reducer)

    assert ET.reduce([1,2,3], inc_trans) == [2,3,4]
  end

  test "ET.stateful/2" do
    take_2 = ET.stateful(
      fn
        _input, 0 -> {:halt, 0}
        input, n  -> {:cont, input, n-1}
      end, 2)
    take_2_trans = ET.compose([take_2], list_reducer)
    assert ET.reduce([1,2,3,4], take_2_trans) == [1,2]
  end

  test "transducer composition" do
    compound_reducer =
      ET.map(fn input -> input + 1 end)
    |> ET.map(fn input -> input * 2 end)
    |> ET.compose(list_reducer)

    assert ET.reduce([1,2,3], compound_reducer) == [4,6,8]
  end
end
