defmodule ETTest do
  use ExUnit.Case

  defmacro list_constructor do
    quote do
      {fn {:init,  [nil]}              -> {:cont, [], [nil]}
          {:cont,  input,  acc, [nil]} -> {:cont, [input | acc], [nil]}
          {:close, acc,    [nil]}      -> {:close, :lists.reverse(acc), [nil]}
       end, [nil]}
    end
  end

  test "ET.compose" do
    inc_transducer = 
      {fn step -> 
            fn {:init, [nil | state]}            -> {msg, return, state} = step.({:init, state})
              {msg, return, [nil | state]}
              {:cont, input, acc, [nil | state]} -> {msg, return, state} = step.({:cont, input + 1, acc, state})
              {msg, return, [nil | state]}
              {:close, acc, [nil | state]}       -> {msg, return, state} = step.({:close, acc, state})
              {msg, return, [nil | state]}
          end
       end, nil}
    assert {inc_trans, [nil, nil]} = ET.compose([inc_transducer], list_constructor)
    assert inc_trans.({:init, [nil, nil]})         == {:cont, [], [nil, nil]}
    assert inc_trans.({:cont, 0, [2], [nil, nil]}) == {:cont, [1, 2], [nil, nil]}
    assert inc_trans.({:close, [2,1], [nil, nil]}) == {:close, [1, 2], [nil, nil]}
  end

  
end
