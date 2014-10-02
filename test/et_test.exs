defmodule ETTest do
  use ExUnit.Case

  defmacro list_constructor do
    quote do
      {fn [nil]               -> {:cont, {[], [nil]}}
          {input, acc, [nil]} -> {:cont, {[input | acc], [nil]}}
          {acc, [nil]}        -> {:halt, {:lists.reverse(acc), [nil]}}
       end, [nil]}
    end
  end

  test "ET.compose/2" do
    inc_transducer = 
      {fn step -> fn trans_wrap ->
         {msg, {acc, state}} = 
           case trans_wrap do
             [nil | state]               -> step.(state)
             {acc, [nil | state]}        -> step.({acc, state})
             {input, acc, [nil | state]} -> step.({input + 1, acc, state})
           end
         {msg, {acc, [nil | state]}}
       end end, nil}

    assert {inc_trans, [nil, nil]} = ET.compose([inc_transducer], list_constructor)
    inc_tests({inc_trans, [nil, nil]})
  end

  test "ET.mapping/1" do
    [ET.mapping(fn input -> input + 1 end)]
    |> ET.compose(list_constructor)
    |> inc_tests
  end

  defp inc_tests({inc_trans, state}) do
    assert inc_trans.(state)           == {:cont, {[], [nil, nil]}}
    assert inc_trans.({0, [2], state}) == {:cont, {[1, 2], [nil, nil]}}
    assert inc_trans.({[2,1], state})  == {:halt, {[1, 2], [nil, nil]}} 
  end

  test "ET.reduce/3" do
    inc_trans = [ET.mapping(&(&1+1))]
      |> ET.compose(list_constructor)

    assert ET.reduce([1,2,3], [], inc_trans) == [2,3,4]
  end

  test "ET.reduce/2" do
    inc_trans = [ET.mapping(&(&1+1))]
      |> ET.compose(list_constructor)

    assert ET.reduce([1,2,3], inc_trans) == [2,3,4]
  end

  test "ET.stateful_transducer/2" do
    take_2 = ET.stateful_transducer(
      fn
        _input, acc, 0 -> {:halt, acc, 0}
        input, acc, n -> {:cont, input, acc, n-1}
      end, 2)
    take_2_trans = ET.compose([take_2], list_constructor)
    assert ET.reduce([1,2,3,4], take_2_trans) == [1,2]
  end
end
