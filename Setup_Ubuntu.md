Setup Email Uploader in Ubuntu
==============================

ex: Your domain is 'example.com' and email post to 'publish-localwiki@example.com'. Please replace this domain and user name.

# Add user

    $ sudo adduser publish-localwiki

# Setup postfix

    $ sudo apt-get install postfix
    $ vim /etc/postfix/main.cf
    smtpd_recipient_restrictions =
        permit_mynetworks,
        check_recipient_access hash:/etc/postfix/access,
        reject
    $ sudo vim /etc/postfix/access
    * REJECT
    publish-localwiki@example.com OK
    $ sudo postmap /etc/postfix/access
    $ sudo /etc/init.d/postfix restart

# Install depend package

RMagick require ImageMagick Development package.

    $ sudo apt-get install libmagickcore-dev
    $ sudo apt-get install libmagickwand-dev

# Setup ruby environment to publish-localwiki user

Install rbenv and ruby 1.9.3-p327 to publish-localwiki user.

    $ sudo su - publish-localwiki
    $ git clone git://github.com/sstephenson/rbenv.git ~/.rbenv
    $ echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.profile
    $ echo 'eval "$(rbenv init -)"' >> ~/.profile
    $ exec $SHELL -l
    $ git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
    $ rbenv rehash
    $ rbenv install 1.9.3-p327
    $ rbenv global 1.9.3-p327

# Setup application

    $ sudo su - publish-localwiki
    $ mkdir app
    $ cd app
    $ git clone git://github.com/Georepublic/localwiki_email_uploader.git
    $ cd localwiki_email_uploader/
    $ cp sample/rbenv-entrypoint.sh app.sh
    $ chmod +x app.sh
    $ gem install bundle
    $ rbenv rehash
    $ bundle install
    $ cp api_settings.rb.example api_settings.rb
    $ vim api_settings.rb

api_settings.rb information provide from admin interface. see: http://example.com/admin

Finally create .forward file.

    $ vim /home/publish-localwiki/.forward
    | ~/app/localwiki_email_uploader/app.sh
