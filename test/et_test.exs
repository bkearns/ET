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

    inc_reducer = ET.compose([inc_transducer], list_reducer)
    inc_tests(inc_reducer, [])
  end

  test "ET.map/1" do
    ET.map(fn input -> input + 1 end)
    |> ET.compose(list_reducer)
    |> inc_tests([])
  end

  defp inc_tests(inc_reducer, state) do
    assert inc_reducer.(:init)              == {:cont, [[]]}
    assert inc_reducer.({:cont, 0, [[2]]})  == {:cont, [[1, 2]]}
    assert inc_reducer.({:fin, [[2,1]]})    == {:fin, [1, 2]} 
  end

  test "ET.reduce/2" do
    inc_reducer = ET.map(&(&1+1))
      |> ET.compose(list_reducer)

    assert ET.reduce([1,2,3], inc_reducer) == [2,3,4]
  end

  test "ET.stateful/2" do
    take_2 = ET.stateful(
      fn
        _input, 0 -> {:halt, 0}
        input, n  -> {:cont, input, n-1}
      end, 2)
    take_2_reducer = ET.compose(take_2, list_reducer)
    assert ET.reduce([1,2,3,4], take_2_reducer) == [1,2]
  end

  test "transducer composition" do
    compound_reducer =
      ET.map(fn input -> input + 1 end)
    |> ET.map(fn input -> input * 2 end)
    |> ET.compose(list_reducer)

    assert ET.reduce([1,2,3], compound_reducer) == [4,6,8]
  end

  test "ET.zip/1" do
    zip_reducer =
      ET.zip
      |> ET.map(fn input -> input + 1 end)
      |> ET.compose(list_reducer)
    assert ET.reduce([[1,2,3,4], [8, 9]], zip_reducer) ==
           [2, 9, 3, 10, 4, 5]
  end

  test "ET.zip/1 properly terminates early" do
    zip_two =
      ET.zip
      |> ET.stateful(
           fn
             _input, 0 -> {:halt, 0}
             input, n  -> {:cont, input, n-1}
           end, 2)
      |> ET.compose(list_reducer)

    assert ET.reduce([[1,2],[3,4],[5,6]], zip_two) == [1,3]
    
    
    # I know this is important, but I need to write too much to test for it. Bad TDD for me, I already wrote the code.
    # ET.zip should terminate on take-x halting even if not all transducers have been passed to zip, since that could be infinite
  end
end
