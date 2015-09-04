## Callbacks

Callbacks provide a way to inject optional functionality
or custom functionality into `sfn` commands. Callbacks
are generally invoked in two places:

* `before` - Prior to the command's remote API request
* `after` - Following the command's remote API request

### Enabling Callbacks

Callbacks can be applied globally (to all commands) or
to specific commands. For example, applying a before callback
to _all_ commands:

```ruby
Configuration.new do
  callbacks.before ['custom_callback']
end
```

Applying a before callback to only the `create` command:

```ruby
Configuration.new do
  callbacks.before_create ['custom_callback']
end
```

The other place a callback can be invoked is after a
template has been loaded. This can allow the callback
to perform some action on the loaded template prior to
the command being executed. Enabling a template callback:

```ruby
Configuration.new do
  callbacks.template ['my-custom-callback']
end
```

When a stack does not include nested stacks, a `before`
callback can be sufficient for allowing modificiations
to a template prior to the command being executed. However,
when a stack contains nested stacks, those templates will
be processed and stored prior to the invocation of any
registered `before` callbacks. For this reason, it is
best to use the `template` callback when registering callbacks
that modify a template contents.

Finally, because callbacks can be distributed via gem it
may be required to load the libraries so the callback is
accessible:

```ruby
Configuration.new do
  callbacks.require ['my-custom-callback']
end
```

### Builtin Callbacks

Builtin callbacks distributed with `sfn`:

* Stack Policy

#### Stack Policy Callback

The Stack Policy Callback utilizes the [policy feature][sparkle_policy]
built into the [SparkleFormation][sparkle_formation] library.
To enable the callback:

```ruby
Configuration.new do
  callbacks do
    default ['stack_policy']
  end
end
```

### Custom Callbacks

To create a custom callback define a new class within the callback namespace
and subclass the abstract class:

```ruby
module Sfn
  class Callback
    class MyCallback < Callback
    end
  end
end
```

Providing a method that matches the callback name requested will enable
its functionality. For example, running an action after every command:

```ruby
module Sfn
  class Callback
    class MyCallback < Callback

      def after(args)
        # do things
      end

    end
  end
end
```

or after the `create` command:

```ruby
module Sfn
  class Callback
    class MyCallback < Callback

      def after_create(args)
        # do things
      end

    end
  end
end
```

The `args` referenced above will be a `Hash` composed of some or all of
the following:

* `:api_stack` - The `Miasma::Models::Orchestration::Stack` instance of the remote stack
* `:stack_name` - Name of the stack
* `:sparkle_stack` - The `SparkleFormation` instance of the template
* `:hash_stack` - The `Hash` instance of the template

Enabling the custom callback is the same as above:

```ruby
Configuration.new do
  callbacks.after ['custom_callback']
end
```
