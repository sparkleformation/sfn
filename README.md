# Knife CloudFormation

A plugin for the knife command provided by Chef to
interact with AWS CloudFormation.

## Compatibility

This plugin now provides support for other cloud
orchestration APIs as well:

* OpenStack
* Rackspace

## Configuration

The easiest way to configure the plugin is via the
`knife.rb` file. Credentials are the only configuration
requirement, and the `Hash` provided is proxied to
Miasma:

```ruby
# .chef/knife.rb

knife[:cloudformation][:credentials] = {
  :aws_access_key_id => ENV['AWS_ACCESS_KEY_ID'],
  :aws_secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
  :aws_region => ENV['AWS_REGION']
}
```

If are using Rackspace:

```ruby
# .chef/knife.rb

knife[:cloudformation][:credentials] = {
  :rackspace_username => ENV['RACKSPACE_USERNAME'],
  :rackspace_api_key => ENV['RACKSPACE_API_KEY'],
  :rackspace_region => ENV['RACKSPACE_REGION']
}
```

If are using OpenStack:

```ruby
# .chef/knife.rb

knife[:cloudformation][:credentials] = {
  :open_stack_username => ENV['OPENSTACK_USERNAME'],
  :open_stack_password => ENV['OPENSTACK_PASSWORD'],
  :open_stack_identity_url => ENV['OPENSTACK_IDENTITY_URL'],
  :open_stack_tenant_name => ENV['OPENSTACK_TENANT']
}
```

## Commands

* `knife cloudformation list`
* `knife cloudformation create`
* `knife cloudformation update`
* `knife cloudformation destroy`
* `knife cloudformation events`
* `knife cloudformation describe`
* `knife cloudformation inspect`
* `knife cloudformation validate`

# Info

* Repository: https://github.com/hw-labs/knife-cloudformation
* IRC: Freenode @ #heavywater