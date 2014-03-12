LocalWiki Email Uploader
========================

LocalWiki content uploader from email using [LocalWiki API].
Email subject is used LocalWiki's page name.
If LocalWiki's page doesn't exist, create page and map, and upload jpeg file.
If LocalWiki's page exist, upload jpeg file, and modify page(don't modify map).

[LocalWiki API]: http://localwiki.readthedocs.org/en/latest/api.html "API Documentation"

## Setup

This is ruby script, install ruby 1.9.3 and follow:

    $ gem install bundler
    $ bundle install --path vendor/bundle
    $ cp api_settings.rb.example api_settings.rb
    $ vim api_settings.rb
    (edit your setting)

And setup your .forward file. For example, if you use rbenv:

    $ cp sample/rbenv-entrypoint.sh app.sh
    $ chmod +x app.sh
    $ vim ~/.forward
    | <your path>/localwiki_email_uploader/app.sh

Please check rbenv-entrypoint.sh, this file has many hints.

If you setup in Ubuntu, see also: [Setup Email Uploader in Ubuntu]

[Setup Email Uploader in Ubuntu]: https://github.com/Georepublic/localwiki_email_uploader/blob/master/Setup_Ubuntu.md "Setup Email Uploader in Ubuntu"

## app_settings.rb

ex: LocalWiki's instance run "http://example.com" and create user "mail" and generate api_key "xxx" and add tag "frommail".

    def get_setting
      return {
        :base_url => 'http://localwiki.net/api/v4',
        :user_name => 'mailuser',
        :api_key => 'xxx',
        # Pick a region URL here -
        :region => 'http://localwiki.net/api/v4/regions/2/',
        :tag_slug => 'frommail'
      }
    end

## Test

Save email and follow:

    $ cat test.eml | bundle exec ruby parser.rb

## Note

This script designed for our customer.
Please hack as you please.

## License

Released under the MIT license.

