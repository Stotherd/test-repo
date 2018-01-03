# GitKeep.

The objective of this tool is to speed up the generation of pull requests.

For auto complete functionality, copy the 2 .git*-completion files to your ~/ directory, and add the following to your bash_profile:

`if [ -f ~/.git-completion.bash ]; then
  . ~/.git-completion.bash
fi`

`if [ -f ~/.gittool-completion.bash ]; then
  . ~/.gittool-completion.bash
fi`

Run bundler install

Then, run the setup command to configure for use. Supply your oauth token from github and this will be added to your keychain along with an email address you want to send from, using the command:

`./gitkeep setup -o [OAUTH_TOKEN] -e [EMAIL_ADDRESS]`

You will then be promoted for your email password which will be stored in your keychain:

`Enter email password:`

And then you're ready to use the script.

To perform an interactive forward merge:

`./gitkeep forward_merge --base_branch [BASE_BRANCH_NAME] --merge_branch [BRANCH_TO_BE_MERGED_IN]`

The command can also be given with -a, and a series of parameters to automatically run through the merge request, except for any conflicts which will need manually resolved.
-p will push the created branch to origin
-g will generate a pull request (requires -p to be selected)
-f instead will not generate a pull request, but will complete the merge with the base branch.

you can then revert back to the base_branch using:

`./gitkeep clean --base_branch [BASE_BRANCH_NAME] --merge_branch [BRANCH_TO_BE_MERGED_IN] -p`

-p is required to ensure the remote branch is deleted.
