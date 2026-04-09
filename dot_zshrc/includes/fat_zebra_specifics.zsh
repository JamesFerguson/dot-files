# awscli defaults
setopt ALL_EXPORT

AWS_PROFILE=test
AWS_DEFAULT_REGION=ap-southeast-2
AWS_SDK_LOAD_CONFIG=true

JABBERWOCKY_DEBUG=true
JABBERWOCKY_PORT=$(<~/.puma-dev/jabberwocky)
JABBERWOCKY_WORKERS=1

PGGSSENCMODE="disable" # fix random segfaults in JW pg gem

SAML2AWS_AUTO_BROWSER_DOWNLOAD=true

# So that switch-mock's SFTP server port doesn't clash with Ruby LSP
SFTP_PORT=2223

unsetopt ALL_EXPORT

# optional
alias saml2aws='saml2aws --skip-prompt' # get username from config and pwd through Okta, don't ask
alias sal='saml2aws login'
alias gbname='git rev-parse --abbrev-ref HEAD' # bare branch name
  # quick open builds for current project
alias bk="buildkite_open"
alias fgd="sal && fargate_deploy"

function current_project() {
  if [[ "$(basename $(dirname $(pwd)))" == *"-worktrees" ]] && [[ -f .git ]] && [[ $(cat .git) =~ gitdir:.*code/([^/]+)/\.git/worktrees ]]; then
    echo "${match[1]}" | tr "_" "-"
  else
    basename $(pwd) | tr "_" "-"
  fi
}

## Functions

# buildkite jump to current project, current branch builds
function buildkite_open() {
  # Use the base name of the current directory
  local project_name=$(current_project)
  local current_branch=$(gbname)

  open "https://buildkite.com/fat-zebra/$project_name/builds?branch=$current_branch"
}

# fargate shortcut using project root dirname and current git branch name
# function fargate_deploy() {
#   # Get the base name of the current directory
#   local project_name=$(current_project)

#   # Check if a build number is supplied
#   if [ -z "$1" ]; then
#     echo "Usage: fargate_deploy <build number>\nAlias usage: fgd <build number>"
#     return 1
#   fi

#   # Construct the image URI
#   local build_number=$1
#   local image_uri="748746525051.dkr.ecr.ap-southeast-2.amazonaws.com/$project_name:$project_name-$project_name-build-$build_number"

#   # Run the fargate-connect command with the constructed image URI
#   fargate-connect -env=test -service="$project_name" -image="$image_uri"
# }
function fargate_deploy() {
  # Check if a build number is supplied
  # if [ -z "$1" ]; then
  #   echo -e "Usage: fargate_deploy <build number>\nAlias usage: fgd <build number>"
  #   return 1
  # fi

  saml2aws login # either prompt login or will do nothing if already logged in

  # Match Jira ticket IDs in branch name
  local jira_pattern="^([A-Za-z]{2,7}\-[0-9]{1,5})[^0-9]"

  # If the branch name starts with a Jira ticket id, give that as the reason
  local branch_name=$(gbname)
  local reason_arg=""
  if [[ $branch_name =~ $jira_pattern ]]; then
    local jira_ticket=${match[1]}

    # the rest of the branch name after the jira ticket id
    local branch_name_remainder=${branch_name#$jira_ticket}
    branch_name_remainder=${branch_name_remainder//[-_]/ } # s/[-_]/ /
    branch_name_remainder=${branch_name_remainder## } # strip left
    branch_name_remainder=$(echo "$branch_name_remainder" | awk '{print toupper(substr($0,0,1)) tolower(substr($0,2))}') # capitalize first char

    default_reason="Testing $jira_ticket. $branch_name_remainder."
  fi

  # Prompt for reason, showing the default reason
  echo -n "Enter reason for deployment [${default_reason}]: "
  read user_reason
  reason_arg="-reason=\"${user_reason:-$default_reason}\""

  local project_name=$(current_project) # pwd.basename.gsub(/_/, '-')
  # Construct the image URI
  # local build_number=$1 # user supplied until figure out some BK api wizardry
  # local image_uri="748746525051.dkr.ecr.ap-southeast-2.amazonaws.com/$project_name:$project_name-$project_name-build-$build_number"

  # echo "fargate-connect -env=test -service=\"$project_name\" -image=\"$image_uri\" $reason_arg"
  echo "fargate-connect -service=\"$project_name\" $reason_arg"
  # Run the fargate-connect command with the constructed image URI and optional reason argument
  # fargate-connect -env=test -service="$project_name" -image="$image_uri" $reason_arg
  fargate-connect -service="$project_name" $reason_arg
}
