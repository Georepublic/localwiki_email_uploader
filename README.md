Localwiki Email Uploader
========================

Localwiki content uploader from email using [Localwiki API].
Email must contain attachment jpeg file and jpeg file must contain location.
Email subject is used Localwiki's page name.
If Localwiki's page doesn't exist, create page and map, and upload jpeg file.
If Localwiki's page exist, upload jpeg file, and modify page(don't modify map).

[Localwiki API]: http://localwiki.readthedocs.org/en/latest/api.html "API Documentation"

## Setup

This is ruby script, install ruby 1.9.3 and follow:

    $ gem install bundler
    $ bundle install --path vendor/bundle
    $ cp api_settings.rb.example api_settings.rb
    $ vim api_settings.rb
    (edit your setting)

And setup your smtp server:-)
    
## Test

Save email and follow:

    $ cat test.eml | bundle exec ruby parser.rb

## Note

This script designed for our customer.
Please hack as you please.

## License

Released under the MIT license.

