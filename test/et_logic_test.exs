defmodule ETLogicTest do
  use ExUnit.Case, async: true

  defp identity_trans, do: ET.Transducers.map(&(&1))

  test "ET.Logic.chunk(inner_reducer)" do
    ET.Logic.chunk(ET.Transducers.take(2) |> ET.Reducers.list)
    |> ET.Reducers.list
    |> chunk_inner_reducer_test
  end

  test "ET.Logic.chunk(transducer, inner_reducer)" do
    identity_trans
    |> ET.Logic.chunk(ET.Transducers.take(2) |> ET.Reducers.list)
    |> ET.Reducers.list
    |> chunk_inner_reducer_test
  end

  defp chunk_inner_reducer_test(reducer) do
    ET.reduce([{1, false}, {2, true}, {3, false}, {4, true}], reducer)
    [[{2, true}, {3, false}]]
  end

  test "ET.Logic.chunk(inner_reducer, padding)" do
    ET.Logic.chunk((ET.Transducers.take(2) |> ET.Reducers.list), [])
    |> ET.Reducers.list
    |> chunk_inner_reducer_padding_test
  end

  test "ET.Logic.chunk(transducer, inner_reducer, padding)" do
    identity_trans
    |> ET.Logic.chunk((ET.Transducers.take(2) |> ET.Reducers.list), [])
    |> ET.Reducers.list
    |> chunk_inner_reducer_padding_test
  end

  defp chunk_inner_reducer_padding_test(reducer) do
    assert ET.reduce([{1, false}, {2, true}, {3, false}, {4, true}], reducer) ==
    [[{2, true}, {3, false}], [{4, true}]]
  end

  test "ET.Logic.chunk(inner_reducer, padding) with extra padding" do
    reducer =
      ET.Logic.chunk((ET.Transducers.take(2) |> ET.Reducers.list), 5..8)
      |> ET.Reducers.list
      
    assert ET.reduce([{1, false}, {2, true}, {3, false}, {4, true}], reducer) == 
    [[{2, true}, {3, false}], [{4, true}, {5, nil}]]    
  end
  
  test "ET.Transducers.destructure()" do
    ET.Logic.destructure
    |> ET.Reducers.list
    |> destructure_test
  end

  test "ET.Transducers.destructure(transducer)" do
    identity_trans
    |> ET.Logic.destructure
    |> ET.Reducers.list
    |> destructure_test
  end

  defp destructure_test(reducer) do
    assert ET.reduce([{1, true}, {2, false}, {3, true}], reducer) ==
           [1,2,3]
  end

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
    assert ET.reduce([{1, true}, {2, true}, {3, false}, {4, true}], reducer) ==
           [{3, false}]
  end

  
end
