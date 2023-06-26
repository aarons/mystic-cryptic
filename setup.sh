#!/bin/bash

# check if zip and lrzip is installed
if ! command -v lrzip &>/dev/null; then
  echo "This program relies on lrzip, please install before continuing."
  echo "Suggest running: 'brew install lrzip' if you are on a mac"
  echo "homebrew can be install by running: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  exit 1
fi

# check if zip is installed
if ! command -v zip &>/dev/null; then
  echo "This program relies on zip, please install before continuing."
  echo "This is normally included with a mac, not sure how you get to this point..."
  echo "Please be sure zip is available in your shell path (maybe check the output of 'echo \$PATH', and your bash profile in one of these files: .bashrc, .zshrc, .bash_profile, or .zprofile)"
  exit 1
fi

# check if openssl is installed
if ! command -v openssl &>/dev/null; then
  echo "This program relies on openssl, please install before continuing."
  echo "This is normally included with a mac, not sure how you get to this point..."
  echo "Please be sure openssl is available in your shell path (maybe check the output of 'echo \$PATH', and your bash profile in one of these files: .bashrc, .zshrc, .bash_profile, or .zprofile)"
  exit 1
fi

# check if the .env file exists
if [ ! -f .env ]; then
  echo "The .env file does not exist, please create one and try again"
  echo "You can use the .env.example file as a template"
  exit 1
fi

# check if 1password op library is installed
if ! command -v op &>/dev/null; then
  echo "This program relies on 1password op, please install before continuing."
  echo "Suggest running: 'brew install 1password-cli' if you are on a mac"
  echo "homebrew can be install by running: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  exit 1
fi

# check if jq library is installed
if ! command -v jq &>/dev/null; then
  echo "This program relies on jq, please install before continuing."
  echo "Suggest running: 'brew install jq' if you are on a mac"
  echo "homebrew can be install by running: /bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
  exit 1
fi

# eventual tests to add:
# if osx permission model is ok for cron, find (can cron use find for example)
# tell user how to setup full disk access for those if not

# if all checks pass, report that it's good to go
echo "All checks passed, good to go!"
