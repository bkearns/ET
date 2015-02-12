defmodule ETHelpersTest do
  use ExUnit.Case
  import ET.Helpers

  defp identity_trans, do: ET.Transducers.map(&(&1))
  
  test "ET.Helpers.cont(reducer_tuple)" do
    assert ET.Helpers.cont({ET.Reducers.list, {:cont, [[]]}}) == {:cont, [[]]}
    assert ET.Helpers.cont({ET.Reducers.list, {:halt, [[]]}}) == {:halt, [[]]}
  end

  test "ET.Helpers.cont(cont_reducer_tuple, state)" do
    assert ET.Helpers.cont({ET.Reducers.list, {:cont, [[]] }}, :foo) ==
           {:cont, [:foo, []]}
  end

  test "ET.Helpers.cont(halt_reducer_tuple, state)" do
    assert ET.Helpers.cont({ET.Reducers.list, {:halt, [[]] }}, :foo) ==
           {:halt, [:foo, []]}
  end

  test "ET.Helpers.cont_nohalt(reducer)" do
    list_reducer = ET.Reducers.list
    assert ET.Helpers.cont_nohalt({list_reducer, {:halt, [[]]}}) ==
           {:cont, [[]]}
  end

  test "ET.Helpers.cont_nohalt(reducer, state)" do
    list_reducer = ET.Reducers.list
    assert ET.Helpers.cont_nohalt({list_reducer, {:halt, [[]]}}, :foo) ==
           {:cont, [:foo, []]}
  end

  test "ET.Helpers.finish(reducer_tuple)" do
    list_reducer = ET.Reducers.list
    reducer_tuple = {list_reducer, {:cont, [[2,1]]}}
    assert ET.Helpers.finish(reducer_tuple) ==
           {:fin, [1,2]}
  end

  test "ET.Helpers.halt(reducer_tuple)" do
    assert ET.Helpers.halt({ET.Reducers.list, {:cont, [[]]}}) == {:halt, [[]]}
  end

  test "ET.Helpers.halt(reducer_tuple, state)" do
    assert ET.Helpers.halt({ET.Reducers.list, {:cont, [[]]}}, :foo) ==
           {:halt, [:foo, []]}
  end

  test "ET.Helpers.halted?(reducer)" do
    assert ET.Helpers.halted?({ET.Reducers.list, {:cont, [[]]}}) == false
    assert ET.Helpers.halted?({ET.Reducers.list, {:halt, [[]]}}) == true
  end

  test "ET.Helpers.init(reducer)" do
    list_reducer = ET.Reducers.list
    assert ET.Helpers.init(list_reducer) ==
           {list_reducer, {:cont, [[]]}}
  end

  test "ET.Helpers.new_transducer(fun)" do
    ET.Helpers.new_transducer(
      fn 3, reducer -> halt(reducer)
         n, reducer -> n |> reduce(reducer) |> cont
      end
    )
    |> ET.Reducers.list
    |> new_transducer_fun_test
  end

  test "ET.Helpers.new_transducer(transducer, fun)" do
    identity_trans
    |> ET.Helpers.new_transducer(
         fn 3, reducer -> halt(reducer)
            n, reducer -> n |> reduce(reducer) |> cont
         end
       )
    |> ET.Reducers.list
    |> new_transducer_fun_test
  end

  defp new_transducer_fun_test(halt_on_3) do
    assert ET.reduce(1..4, halt_on_3) == [1,2]
  end
  
  test "ET.Helpers.new_transducer(fun, fun, fun)" do
    ET.Helpers.new_transducer(
      fn reducer -> reducer |> init |> cont(2) end,
      fn
        elem, reducer, 0 ->
          elem
          |> reduce(reducer)
          |> halt(0)
        elem, reducer, count ->
          elem
          |> reduce(reducer)
          |> cont(count-1)
      end,
      fn reducer, _ -> finish(reducer) end
    )
    |> ET.Reducers.list
    |> new_transducer_fun_fun_fun_test
  end

  test "ET.Helpers.new_transducer(transducer, fun, fun, fun)" do
    identity_trans
    |> ET.Helpers.new_transducer(
      fn reducer -> reducer |> init |> cont(2) end,
      fn
        elem, reducer, 0 ->
          elem
          |> reduce(reducer)
          |> halt(0)
        elem, reducer, count ->
          elem
          |> reduce(reducer)
          |> cont(count-1)
      end,
      fn reducer, _ -> finish(reducer) end
    )
    |> ET.Reducers.list
    |> new_transducer_fun_fun_fun_test
  end

  defp new_transducer_fun_fun_fun_test(take_three) do
    assert ET.reduce(1..4, take_three) == [1,2,3]
    assert ET.reduce(1..2, take_three) == [1,2]
  end

  test "ET.Helpers.reduce(elem, cont_reducer_tuple)" do
    list_reducer = ET.Reducers.list
    reducer_tuple = {list_reducer, {:cont, [[]]}}
    assert ET.Helpers.reduce(:foo, reducer_tuple) ==
           {list_reducer, {:cont, [[:foo]]}}
  end

  test "ET.Helpers.reduce(elem, halt_reducer_tuple)" do
    list_reducer = ET.Reducers.list
    reducer_tuple = {list_reducer, {:halt, [[]]}}
    assert_raise FunctionClauseError, fn -> ET.Helpers.reduce(:foo, reducer_tuple) end
  end

  test "ET.Helpers.reduce_many(transducible, reducer)" do
    list_reducer = ET.Reducers.list
    assert ET.Helpers.reduce_many(1..4, {list_reducer, {:cont, [[]]}}) ==
           {list_reducer, {:cont, [[4,3,2,1]]}}
  end

  test "ET.Helpers.reduce_many(transducible, reducer) early termination" do
    take_two_list_reducer = ET.Transducers.take(2) |> ET.Reducers.list
    assert ET.Helpers.reduce_many(1..4, {take_two_list_reducer, {:cont, [1, []]}}) ==
           {take_two_list_reducer, {:halt, [1, [2,1]]}}
  end

  test "ET.Helpers.reduce_one(transducible, reducer)" do
    list_reducer = ET.Reducers.list
    assert ET.Helpers.reduce_one([1,2,3], {list_reducer, {:cont, [[]]}}) ==
           {[2,3], {list_reducer, {:cont, [[1]]}}}
    assert ET.Helpers.reduce_one([], {list_reducer, {:cont, [[]]}}) ==
           {:done, {list_reducer, {:cont, [[]]}}}
  end
end
