bundle_commands=( cap compass cucumber foreman guard jammit rackup rails rake rdebug rspec sidekiq spec spring watchr )

function run_bundler_cmd () {
  if [ -e ./Gemfile ]; then
    echo "bundle exec $@"
    bundle exec $@
  else
    echo "$@"
    $@
  fi
}

for cmd in $bundle_commands
do
  alias $cmd="run_bundler_cmd $cmd"
done
