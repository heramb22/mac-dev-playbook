#!/usr/bin/env bash

#defaults write com.apple.finder AppleShowAllFiles YES; # show hidden files
#defaults write com.apple.dock persistent-apps -array; # remove icons in Dock
#defaults write com.apple.dock tilesize -int 36; # smaller icon sizes in Dock
#defaults write com.apple.dock autohide -bool true; # turn Dock auto-hidng on
#defaults write com.apple.dock autohide-delay -float 0; # remove Dock show delay
#defaults write com.apple.dock autohide-time-modifier -float 0; # remove Dock show delay
#defaults write com.apple.dock orientation right; # place Dock on the right side of screen
#defaults write NSGlobalDomain AppleShowAllExtensions -bool true; # show all file extensions
#killall Dock 2>/dev/null;
#killall Finder 2>/dev/null;

# install Xcode Command Line Tools
# https://github.com/timsutton/osx-vm-templates/blob/ce8df8a7468faa7c5312444ece1b977c1b2f77a4/scripts/xcode-cli-tools.sh
echo 'Installing Xcode Command Line Tools...'
touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress;
PROD=$(softwareupdate -l |
  grep "\*.*Command Line" |
  head -n 1 | awk -F"*" '{print $2}' |
  sed -e 's/^ *//' |
  tr -d '\n')
softwareupdate -i "$PROD" -v;


# We need at least ansible 2.0 for blockinfile directive
ANSIBLE_NEEDED="2.0"

# Returns 1 if upgrade is needed
# $1 - SYSTEM VERSION
# $2 - NEEDED VERSION
update_needed () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 0
        fi
    done
    return 0
}

## Add write permission for /usr/local for admin group
sudo chown -R $(whoami):admin /usr/local

## Install or Update Homebrew ##
## ToDo: Automate Homebrew install so that 'Return' key isn't needed to create directories.
echo 'Installing or Updating Homebrew...'
which -s brew
if [[ $? != 0 ]] ; then
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
else
    brew update
fi
echo -e "\n\n"


## Install or Update Ansible ##
echo 'Installing or Updating Ansible...'
which -s ansible-playbook
if [[ $? != 0 ]] ; then
  echo "ansible installation..."
    brew install ansible
else # Ansible needs to be at least 1.9
  ANSIBLE_VERSION=$(ansible --version | grep ansible | cut -d " " -f 2)
  if update_needed $ANSIBLE_VERSION $ANSIBLE_NEEDED; then
    echo "Ansible is too old: $ANSIBLE_VERSION. We need >$ANSIBLE_NEEDED"
    echo "Updating ansible through homebrew..."
    brew upgrade ansible
    brew link --overwrite ansible
  else
    echo "Ansible version is $ANSIBLE_VERSION. Update not needed..."
  fi
fi
echo -e "\n\n"

## Check out a copy of this repo (first time only) ##
echo 'Checking out MADE (Mac Automated Development Environment) repo...'
git clone https://github.com/heramb22/made.git /usr/local/made 2>/dev/null

## Run Ansible Playbook ##
echo 'Handing Playbook to Ansible (will require your sudo password)...'
echo -e "\n\n"
#/usr/local/dev-env/bin/dev update
cd /usr/local/made/
ansible-galaxy install -r requirements.yml
ansible-playbook main.yml -i inventory --ask-sudo-pass --verbose
