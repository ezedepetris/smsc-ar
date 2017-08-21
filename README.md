# Smsc-ar

Welcome to smc-ar the gem to send sms via (www.smsc.com.ar).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'smsc-ar', '~> 0.0.1'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install smsc-ar

## Usage

Create a instance
```ruby
sms = Smsc.new("your_alias", "your_apikey")
```
And then..
Check if the service is active
```ruby
sms.active?

# => true
```
Check the service status 
```ruby
sms.status

# => {:code=>200, :message=>""}
```
Check your account balance
```ruby
sms.balance

# => 557
```
Check the messages received
```ruby
sms.received

# => {:id=>"8324966", :date=>"2017-07-19T02:01:02Z", :message=>"#14691 message test", :from=>"0", :phone=>"0"}
```
Check the messages sent
```ruby
sms.sent

# => {:id=>"8889563", :date=>"2017-08-09T00:51:52Z", :message=>"#14691 message test", :recipients=>[{:code_area=>"3584", :phone=>"316256", :status=>"Entregado"}]}
```
Send a SMS
```ruby
sms.send("your_phone_number", "your_message") # Example sms.send("0358-154316256","Hey, Casper, Are you there?")

# => true
```
See the messages enqueued to send later
```ruby
# priority 0:all 1:low 2:mid 3:hight

sms.enqueued(0)

# => 7234
```
Check if the number is valid to send a sms
```ruby
sms.valid_phone?('0358-154316256')

# => true
```
Cancel all messages enqueued
```ruby
sms.cancel_queue

# => true
```
Check if the last action have errors
```ruby
sms.errors?

# => false
```
Retrieve the errors of the last action
```ruby
sms.errors

# => "Unauthorized access"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ezedepetris/smsc-ar. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

