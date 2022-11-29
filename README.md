# ExPipeline

![Build Status](https://github.com/msramos/ex_pipeline/actions/workflows/ci.yml/badge.svg?branch=main)
[![Module Version](https://img.shields.io/hexpm/v/ex_pipeline.svg)](https://hex.pm/packages/ex_pipeline)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/ex_pipeline/)
[![License](https://img.shields.io/hexpm/l/ex_pipeline.svg)](https://github.com/msramos/ex_pipeline/blob/main/LICENSE)

ExPipeline is an opinionated library to build better pipelines.

A pipeline is set of functions that must be executed in a specific order to transform an initial state into a desired
state. For example, a "login pipeline" uses the request body as its initial state and generates an authentication token.

It allows a feature to expressed as a set of functions, like the following snippet:

```elixir
defmodule MyFeature do
  use Pipeline

  def parse_step(value, options) do
    ...
  end

  def fetch_address_step(value, options) do
     ...
  end

  def final_step(value, options) do
    ...
  end

  def reporter_async_hook(%Pipeline.State{} = state, options) do
    ...
  end
end
```

Later on, you can execute this feature by calling the generated `execute/2` function or the `Pipeline.execute/3`
function:

```elixir
MyFeature.execute(some_value, some_options)
# or
Pipeline.execute(MyPipeline, some_value, some_options)
```

These functions will return an ok/error tuple, so you can execute them with a `case` block , for example:

```elixir
case MyFeature.execute(params, options) do
  {:ok, succesful_result} ->
    ...

  {:error, error_description} ->
    ...
end
```

## Creating Pipelines

To create a pipeline, the target module **must** `use Pipeline`, and the functions must follow some patterns.

* Functions that are part of the pipeline must end with `_step`, `_hook` or `_async_hook`.
* They must accepts two parameters

### Steps

Each step modify a _state_. The result of one step is given to the next step, until the last step. Then the result
is evaluated and returned.

* Steps are executed in the same order that they are declared.
* The first parameter is whatever was passed to the pipeline, and each step transforms this value to the next value.
* The second parameter is an optional and immutable keyword list that is passed to all steps.
* A step **must** return an ok/error tuple - `{:ok, any}` or `{:error, any}`.
* If one step fails, the next steps are not executed.

### Hooks and Async Hooks

Hooks and async hooks are executed after all steps have completed, regardless of their result.

* Async hooks are functions whose name end with `_async_hook` and hooks are functions whose name end with `_hook`.
* Both types of hooks  **must** accept two parameters. The difference is that hooks receive the final `Pipeline.State`
struct with the execution result. Hooks return are ignored.
  * The first parameter is the last version of the `Pipeline.State` struct from the evaluation of the last step.
  * The second parameter is the same optional and immutable keyword list that is passed to all step.
* After all steps are executed, the pipeline will launch all __async hooks__ on isolated processes, and run them in
  parallel.
* After all steps are executed, the pipeline will execute all __hooks__, in the same order that they were declared.


## Why?

As features get more complex with time, Elixir pipes and `with` blocks can become harder to understand. Also, functions
that are added to them over time don't really have a spec to follow.

Let's take this simple checkout code as example:

```elixir
with %Payment{} = payment <- fetch_payment_information(params),
     {:ok, user} <- Session.get(conn, :user),
     address when !is_nil(address) <- fetch_address(user, params),
     {:ok, order} <- create_order(user, payment, address) do
  conn
  |> put_flash(:info, "Order completed!")
  |> render("checkout.html")
else
  {:error, :payment_failed} ->
    handle_error(conn, "Payment Error")

  %Store.OrderError{message: message} ->
    handle_error(conn, "Order Error")

  error ->
    handle_error(conn, "Unprocessable order")
end
```

We can make it look better by applying some code styles and get something like this:

```elixir
options = %{conn: conn}

with {:ok, payment} <- fetch_payment_information(params, options),
     {:ok, user} <- fetch_user(conn),
     {:ok, address} <- fetch_address(%{user: user, params: params}, options),
     {:ok, order} <- create_order(%{user: user, address: address, payment: payment}, options)
  do
  conn
  |> put_flash(:info, "Order completed!")
  |> redirect(to: Routes.order_path(conn, order))
else
  {:error, error_description} ->
    conn
    |> put_flash(:error, parse_error(error_description))
    |> render("checkout.html")
end
```

This is definitely easier to understand, but since the code style is not enforced, it may not look like this for too
long, specially if it's something that's being actively maintained.

Using `ex_pipeline`, we can express this `with` block like this:

```elixir
case Checkout.execute(params, conn: conn) do
  {:ok, order} ->
    conn
    |> put_flash(:info, "Order completed!")
    |> redirect(to: Routes.order_path(conn, order))

  {:error, error_description} ->
    conn
    |> put_flash(:error, parse_error(error_description))
    |> render("checkout.html")
end
```

Inside `Checkout`, all functions will look the same, and any modifications must also follow the same pattern.

## Installation

Add the [Hex package](https://hex.pm/packages/ex_pipeline) by adding `ex_pipeline` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:ex_pipeline, "~> 0.2.0"}
  ]
end
```

Then make sure the `ex_pipeline` application is being loaded.

## Code of Conduct

This project uses Contributor Covenant version 2.1. Check [CODE_OF_CONDUCT.md](/CODE_OF_CONDUCT.md) file for more information.

## License

`ex_pipeline` source code is released under Apache License 2.0.

Check [NOTICE](/NOTICE) and [LICENSE](/LICENSE) files for more information.
