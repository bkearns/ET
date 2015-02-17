defmodule ETReducersTest do
  use ExUnit.Case, async: true

  defp identity_trans, do: ET.Transducers.map(&(&1))

  test "ET.Reducers.all?()" do
    ET.Reducers.all?
    |> all_test
  end

  test "ET.Reducers.all?(transducer)" do
    identity_trans
    |> ET.Reducers.all?
    |> all_test
  end

  defp all_test (reducer) do
    assert ET.reduce([1, true], reducer) == true
    assert ET.reduce([true, false, true], reducer) == false
    assert ET.reduce([true, nil, true], reducer) == false
  end

  test "ET.Reducers.all?(check_fun)" do
    ET.Reducers.all?(&(&1<4))
    |> all_check_fun_test
  end

  test "ET.Reducers.all?(transducer, check_fun)" do
    identity_trans
    |> ET.Reducers.all?(&(&1<4))
    |> all_check_fun_test
  end

  defp all_check_fun_test(reducer) do
    assert ET.reduce([1,2,3], reducer) == true
    assert ET.reduce([1,2,3,4], reducer) == false
  end

  test "ET.Reducers.any?()" do
    ET.Reducers.any?
    |> any_test
  end

  test "ET.Reducers.any?(transducer)" do
    identity_trans
    |> ET.Reducers.any?()
    |> any_test
  end

  defp any_test(reducer) do
    assert ET.reduce([false, true], reducer) == true
    assert ET.reduce([false, 1], reducer) == true
    assert ET.reduce([false, nil], reducer) == false
  end

  test "ET.Reducers.any?(check_fun)" do
    ET.Reducers.any?(&(&1<2))
    |> any_check_fun_test
  end

  test "ET.Reducers.any?(transducer, check_fun)" do
    identity_trans
    |> ET.Reducers.any?(&(&1<2))
    |> any_check_fun_test
  end

  defp any_check_fun_test(reducer) do
    assert ET.reduce([1,2,3], reducer) == true
    assert ET.reduce([2,3,4], reducer) == false
  end

  test "ET.Reducers.binary()" do
    ET.Reducers.binary
    |> binary_test
  end

  test "ET.Reducers.binary(transducer)" do
    identity_trans
    |> ET.Reducers.binary
    |> binary_test
  end

  defp binary_test(reducer) do
    assert ET.reduce(["h", "e", "ll", 0], reducer) ==
           "hell0"
  end

  test "ET.Reducers.count()" do
    ET.Reducers.count
    |> count_test
  end

  test "ET.Reducers.count(transducer)" do
    identity_trans
    |> ET.Reducers.count
    |> count_test
  end

  defp count_test(reducer) do
    assert ET.reduce([], reducer) == 0
    assert ET.reduce(1..3, reducer) == 3
    assert ET.reduce(1..4, reducer) == 4
  end

  test "ET.Reducers.into(list)" do
    ET.Reducers.into([0])
    |> into_list_test
  end

  test "ET.Reducers.into(transducible, list)" do
    identity_trans
    |> ET.Reducers.into([0])
    |> into_list_test
  end

  defp into_list_test(list_reducer) do
    assert ET.reduce([1,2], list_reducer) == [0,1,2]
  end

  test "ET.Reducers.list()" do
    ET.Reducers.list
    |> list_test
  end

  test "ET.Reducers.list(transducer)" do
    identity_trans
    |> ET.Reducers.list
    |> list_test
  end

  defp list_test(reducer) do
    assert ET.reduce([1,2,3,4], reducer) == [1,2,3,4]
  end

  test "ET.Reducers.last(term)" do
    ET.Reducers.last(:ok)
    |> last_test
  end

  test "ET.Reducers.last(term, transducer)" do
    identity_trans
    |> ET.Reducers.last(:ok)
    |> last_test
  end

  defp last_test(ok_or_last_r_fun) do
    assert ET.reduce(1..6, ok_or_last_r_fun) == 6
    assert ET.reduce([], ok_or_last_r_fun) == :ok
  end

  test "ET.Reducers.map()" do
    ET.Reducers.map
    |> map_test
  end

  test "ET.Reducers.map(transducer)" do
    identity_trans
    |> ET.Reducers.map
    |> map_test
  end

  defp map_test(reducer) do
    assert ET.reduce([one: 1, two: 2, one: 3], reducer) ==
    %{one: 3, two: 2}
  end

  test "ET.Reducers.max()" do
    ET.Reducers.max
    |> max_test
  end

  test "ET.Reducers.max(transnducer)" do
    identity_trans
    |> ET.Reducers.max
    |> max_test
  end

  defp max_test(max_r_fun) do
    assert ET.reduce([2,4,3,1], max_r_fun) == 4
  end

  test "ET.Reducers.max_by(fun)" do
    ET.Reducers.max_by(&(-&1))
    |> max_by_fun_test
  end

  test "ET.Reducers.max_by(transducer, fun)" do
    identity_trans
    |> ET.Reducers.max_by(&(-&1))
    |> max_by_fun_test
  end

  defp max_by_fun_test(max_r_fun) do
    assert ET.reduce([2,4,1,3], max_r_fun) == 1
  end

  test "ET.Reducers.map(fun)" do
    ET.Reducers.map(&(&1+&2))
    |> map_fun_test
  end

  test "ET.Reducers.map(transducer, fun)" do
    identity_trans
    |> ET.Reducers.map(&(&1+&2))
    |> map_fun_test
  end

  defp map_fun_test(adder) do
    assert ET.reduce([one: 1, two: 2, one: 3, two: 4], adder) ==
           %{one: 4, two: 6}
  end

  test "ET.Reducers.static()" do
    ET.Reducers.static
    |> static_test
  end

  test "ET.Reducers.static(transducer)" do
    identity_trans
    |> ET.Reducers.static
    |> static_test
  end

  defp static_test(r_fun) do
    assert ET.reduce(1..5, r_fun) == :ok
  end

  test "ET.Reducers.static(t)" do
    ET.Reducers.static(:error)
    |> static_t_test
  end

  test "ET.Reducers.static(transducer, t)" do
    identity_trans
    |> ET.Reducers.static(:error)
    |> static_t_test
  end

  defp static_t_test(r_fun) do
    assert ET.reduce(1..5, r_fun) == :error
  end
end
