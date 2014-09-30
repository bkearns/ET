ET - Elixir Transducers
=======================

## Why Transducers?

    fn input, accumulator -> [input + 1 | accumulator] end

This incrementing reducing function seems straightforward, but it has a problem. It conflates the transformation and reconstruction steps. In order to use this as part of a composable chain of transformations, we have to ensure the initial collection is a list, save it to an intermediate list between each step, and then convert it from the list at the end.

With transducers, we separate concerns and produce composable functions which transform data and manage control flow without the need to know where this data is coming or where it will go to.

## Status

No documentation and a lot of missing conveniences, but the core is here and implmented in not much code.

I can find surprisingly little on the subject and have based what I have done mostly on (a talk by Rich Hickey)[https://www.youtube.com/watch?v=6mTbuzafcII]. So, resources and thoughts are welcome, although I apologize if I am slow to respond.
