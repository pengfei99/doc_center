# Basic commands in git


## Clean local git repo branches

```shell
# this command will fetch the remote repo branch status, if the branch is deleted in remote repo, it will be also
# deleted in local repo
git remote update origin --prune
```