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
Fog:

```ruby
# .chef/knife.rb

knife[:cloudformation][:credentials] = {
  :aws_access_key_id => ENV['AWS_ACCESS_KEY_ID'],
  :aws_secret_access_key => ENV['AWS_SECRET_ACCESS_KEY'],
  :region => 'us-east-1'
}
```

If are using Rackspace:

```ruby
# .chef/knife.rb

knife[:cloudformation][:credentials] = {
  :rackspace_username => ENV['RACKSPACE_USERNAME'],
  :rackspace_api_key => ENV['RACKSPACE_API_KEY'],
  :rackspace_region => 'ord'
}
```

## Commands

* `knife cloudformation list`
* `knife cloudformation create`
* `knife cloudformation update`
* `knife cloudformation destroy`
* `knife cloudformation events`
* `knife cloudformation export`
* `knife cloudformation import`
* `knife cloudformation describe`
* `knife cloudformation inspect`
* `knife cloudformation validate`

# Info

* Repository: https://github.com/heavywater/knife-cloudformation
* IRC: Freenode @ #heavywater