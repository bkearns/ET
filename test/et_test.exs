defmodule ETTest do
  use ExUnit.Case

  defmacro list_constructor do
    quote do
      fn
        :init                            -> { :cont, [[]] }
        {:init, init} when is_list(init) -> { :cont, [init] }
        {:fin, [acc]}                    -> { :fin, :lists.reverse(acc) }
        {:cont, input, [acc]}            -> { :cont, [[input | acc]] }
      end
    end
  end

  test "ET.compose/2" do
    inc_transducer = 
      fn step ->
        fn
          :init                 -> step.(:init)
          {:init, init}         -> step.({:init, init})
          {:fin, state}         -> step.({:fin, state})
          {:cont, input, state} -> step.({:cont, input + 1, state})
         end
       end

    inc_trans = ET.compose([inc_transducer], list_constructor)
     inc_tests(inc_trans, [])
  end

  test "ET.map/1" do
    [ET.map(fn input -> input + 1 end)]
    |> ET.compose(list_constructor)
    |> inc_tests([])
  end

  defp inc_tests(inc_trans, state) do
    assert inc_trans.(:init)              == {:cont, [[]]}
    assert inc_trans.({:init, [1]})       == {:cont, [[1]]}
    assert inc_trans.({:cont, 0, [[2]]})  == {:cont, [[1, 2]]}
    assert inc_trans.({:fin, [[2,1]]})    == {:fin, [1, 2]} 
  end

  test "ET.reduce/3" do
    inc_trans = [ET.map(&(&1+1))]
      |> ET.compose(list_constructor)

    assert ET.reduce([1,2,3], [], inc_trans) == [2,3,4]
  end

  test "ET.reduce/2" do
    inc_trans = [ET.map(&(&1+1))]
      |> ET.compose(list_constructor)

    assert ET.reduce([1,2,3], inc_trans) == [2,3,4]
  end

  test "ET.stateful/2" do
    take_2 = ET.stateful(
      fn
        _input, 0 -> {:halt, 0}
        input, n  -> {:cont, input, n-1}
      end, 2)
    take_2_trans = ET.compose([take_2], list_constructor)
    assert ET.reduce([1,2,3,4], take_2_trans) == [1,2]
  end
end
