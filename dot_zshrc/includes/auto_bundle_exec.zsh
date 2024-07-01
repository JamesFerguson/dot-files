bundle_commands=( brakeman cap compass cucumber foreman guard jammit rackup rails rake rdebug rspec rubocop sidekiq skylight spec spring srb tapioca watchr whenever )

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
