defmodule ETLogicTest do
  use ExUnit.Case, async: true

  defp identity_trans, do: ET.Transducers.map(&(&1))
  
  test "ET.Logic.filter()" do
    ET.Logic.filter
    |> ET.Reducers.list
    |> filter_test
  end

  test "ET.Logic.filter(transducer)" do
    identity_trans
    |> ET.Logic.filter
    |> ET.Reducers.list
    |> filter_test
  end

  defp filter_test(reducer) do
    assert ET.reduce([{1, false}, {2, false}, {3, true}, {4, false}], reducer) ==
           [{3, true}]
  end

  
end
