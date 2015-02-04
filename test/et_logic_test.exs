defmodule ETLogicTest do
  use ExUnit.Case, async: true

  defp identity_trans, do: ET.Transducers.map(&(&1))

  test "ET.Logic.change?()" do
    ET.Logic.change?
    |> ET.Reducers.list
    |> change_test
  end

  test "ET.Logic.change?(transducer)" do
    identity_trans
    |> ET.Logic.change?
    |> ET.Reducers.list
    |> change_test
  end

  defp change_test(reducer) do
    assert ET.reduce([1,1,1,2,3], reducer) ==
           [{1, false}, {1, false}, {1, false}, {2, true}, {3, true}]
  end

  test "ET.Logic.change?(first: true)" do
    ET.Logic.change?(first: true)
    |> ET.Reducers.list
    |> change_first_true_test
  end

  test "ET.Logic.change?(transducer, first: true)" do
    identity_trans
    |> ET.Logic.change?(first: true)
    |> ET.Reducers.list
    |> change_first_true_test
  end

  defp change_first_true_test(reducer) do
    assert ET.reduce([1,1,1,2,3], reducer) ==
           [{1, true}, {1, false}, {1, false}, {2, true}, {3, true}]
  end

  test "ET.Logic.change?(change_check)" do
    ET.Logic.change?(&(rem(&1, 2)))
    |> ET.Reducers.list
    |> change_change_check_test
  end

  test "ET.Logic.change?(transducer, change_check)" do
    identity_trans
    |> ET.Logic.change?(&(rem(&1, 2)))
    |> ET.Reducers.list
    |> change_change_check_test
  end

  defp change_change_check_test(reducer) do
    assert ET.reduce([1,3,1,2,3], reducer) ==
           [{1, false}, {3, false}, {1, false}, {2, true}, {3, true}]
  end

  test "ET.Logic.change?(change_check, first: true)" do
    ET.Logic.change?(&(rem(&1, 2)), first: true)
    |> ET.Reducers.list
    |> change_change_check_first_true_test
  end

  test "ET.Logic.change?(transducer, change_check, first: true)" do
    identity_trans
    |> ET.Logic.change?(&(rem(&1, 2)), first: true)
    |> ET.Reducers.list
    |> change_change_check_first_true_test
  end

  defp change_change_check_first_true_test(reducer) do
    assert ET.reduce([1,3,1,2,3], reducer) ==
           [{1, true}, {3, false}, {1, false}, {2, true}, {3, true}]
  end

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
  
  test "ET.Logic.destructure()" do
    ET.Logic.destructure
    |> ET.Reducers.list
    |> destructure_test
  end

  test "ET.Logic.destructure(transducer)" do
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

  test "ET.Logic.halt_after()" do
    ET.Logic.halt_after
    |> ET.Reducers.list
    |> halt_after_test
  end

  test "ET.Logic.halt_after(transducer)" do
    identity_trans
    |> ET.Logic.halt_after
    |> ET.Reducers.list
    |> halt_after_test
  end

  defp halt_after_test(reducer) do
    assert ET.reduce([{1, false}, {2, false}, {3, true}, {4, false}], reducer) ==
    [{1, false}, {2, false}, {3, true}]
  end

  test "ET.Logic.halt_on()" do
    ET.Logic.halt_on
    |> ET.Reducers.list
    |> halt_on_test
  end

  test "ET.Logic.halt_on(transducer)" do
    identity_trans
    |> ET.Logic.halt_on
    |> ET.Reducers.list
    |> halt_on_test
  end

  defp halt_on_test(reducer) do
    assert ET.reduce([{1, false}, {2, false}, {3, true}, {4, false}], reducer) ==
    [{1, false}, {2, false}]
  end
  
  test "ET.Logic.true_every(n)" do
    ET.Logic.true_every(2)
    |> ET.Reducers.list
    |> true_every_n_test
  end

  test "ET.Logic.true_every(n, transducer)" do
    identity_trans
    |> ET.Logic.true_every(2)
    |> ET.Reducers.list
    |> true_every_n_test
  end

  defp true_every_n_test(reducer) do
    assert ET.reduce(1..4, reducer) ==
           [{1, false}, {2, true}, {3, false}, {4, true}]
  end

  test "ET.Logic.true_every(n, first: true)" do
    ET.Logic.true_every(2, first: true)
    |> ET.Reducers.list
    |> true_every_n_first_true_test
  end

  test "ET.Logic.true_every(transducer, n, first: true)" do
    identity_trans
    |> ET.Logic.true_every(2, first: true)
    |> ET.Reducers.list
    |> true_every_n_first_true_test
  end

  defp true_every_n_first_true_test(reducer) do
    assert ET.reduce(1..4, reducer) ==
           [{1, true}, {2, false}, {3, true}, {4, false}]
  end

end
