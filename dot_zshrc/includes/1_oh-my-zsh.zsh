# Named 1_... to be loaded first.
######################################################################
#         Oh My Zsh
######################################################################

# Path to your oh-my-zsh configuration.
export ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
# export ZSH_THEME="robbyrussell"
export ZSH_THEME="josh"

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(\
  asdf\
  aws\
  bower\
  brew\
  bundler\
  capistrano\
  chruby\
  cp\
  docker\
  fasd\
  gem\
  git\
  git-extras\
  git-flow\
  git-remote-branch\
  github\
  heroku\
  node\
  npm\
  osx\
  postgres\
  powder\
  rails\
  rake\
  redis-cli\
  screen\
  urltools\
  vundle\
  zeus\
  autojump)

source $ZSH/oh-my-zsh.sh
