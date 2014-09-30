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
      {fn step -> fn trans_wrap ->
         {msg, acc, state} = 
           case trans_wrap do
             {:init, [nil | state]} -> step.({:init, state})
             {:close, acc, [nil | state]} -> step.({:close, acc, state})
             {:cont, input, acc, [nil | state]} -> step.({:cont, input + 1, acc, state})
           end
         {msg, acc, [nil | state]}
       end end, nil}

    assert {inc_trans, [nil, nil]} = ET.compose([inc_transducer], list_constructor)
    inc_tests({inc_trans, [nil, nil]})
  end

  test "ET.mapping" do
    [ET.mapping(fn input -> input + 1 end)]
    |> ET.compose(list_constructor)
    |> inc_tests
  end

  defp inc_tests({inc_trans, state}) do
    assert inc_trans.({:init, state})         == {:cont, [], [nil, nil]}
    assert inc_trans.({:cont, 0, [2], state}) == {:cont, [1, 2], [nil, nil]}
    assert inc_trans.({:close, [2,1], state}) == {:close, [1, 2], [nil, nil]}    
  end
end
