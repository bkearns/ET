defmodule ET.Reducers do

  def list(%ET.Transducer{} = trans), do: ET.Transducer.compose(trans, list())
  def list do
    fn
      :init                            -> { :cont, [[]] }
      {:fin, [acc]}                    -> { :fin, :lists.reverse(acc) }
      {:cont, input, [acc]}            -> { :cont, [[input | acc]] }
    end
  end
end
