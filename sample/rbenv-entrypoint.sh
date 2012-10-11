export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
CWD=`dirname $0`
cd $CWD && bundle exec ruby parser.rb
