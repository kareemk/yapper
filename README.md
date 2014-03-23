yapper [![Build Status](https://travis-ci.org/kareemk/yapper.png?branch=master)](https://travis-ci.org/kareemk/yapper)
======

RubyMotion ORM for the wonderful [YapDatabase](https://github.com/yaptv/YapDatabase). Key features:
* Schemaless (define fields in your models)
* Very fast (thanks to YapDatabase's architecture)
* Chainable criteria
* One-many relationships
* On-the-fly reindexing
* Thread safe

Show me
-------

```ruby
  class User
    include Yapper::Document

    field :name,  :type => String
    field :email, :type => String
    field :bio,   :type => String

    has_many :locations

    index :name, :email
  end

  class Location
    include Yapper::Document

    belongs_to :user

    field :address
    field :city

    index :city
  end

  # Create
  user = User.create(:name => 'John Malkovich')
  location = Location.create(:user => user, :address => 'One Main', :city => 'Brooklyn')

  # Update
  user.update_attributes(:email => 'john@malkovich.com')

  # Wait for a document to exist
  User.when(id) { |user| puts "Got #{user.name}" }

  # Query (note you can only query on indexed fields)
  User.where(:email => 'john@malkovich.com')

  # Return all documents
  User.all

  # Chain queries
  User.where(:email => 'john@malkovich.com').where(:name => "John")

  # Count
  User.count
  User.where(:email => 'john@malkovich.com').where(:name => "John").count

  # Limit
  User.where(:email => 'john@malkovich.com').where(:name => "John").limit(1)

  # First
  User.where(:email => 'john@malkovich.com').where(:name => "John").first

  # Last
  User.where(:email => 'john@malkovich.com').where(:name => "John").last

  # On relations
  user.locations.where(:city => 'Brooklyn').first

```

See the [specs](https://github.com/kareemk/yapper/tree/master/spec/integration)
for more detail.

Status
------

*Beta*. There are a lot of features missing that you'll probably want.
Open an [Issue](https://github.com/kareemk/yapper/issues) or better yet create a
pull request and let's make this happen.

Current roadmap:
* Performance optimizations (using a read-only connection on the main thread)
* Richer querying (not, or, custom sql)
* [Views](https://github.com/yaptv/YapDatabase/wiki/Views)
* [Full-text search](https://github.com/yaptv/YapDatabase/wiki/Full-Text-Search)
* RESTful API support


Prerequisites
-------------

Motion CocoaPods
```ruby
gem install motion-cocoapods
pod setup
```

Install
-------

```ruby
gem install motion-yapper
```
or add the following line to your Gemfile:
```ruby
gem 'motion-yapper'
```
and run `bundle install`

License
-------
Copyright (C) 2013 Kareem Kouddous

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
