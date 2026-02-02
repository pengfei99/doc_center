# Git Tagging

Like most VCSs, Git has the ability to `tag specific points` in a repository’s history as being important. Typically, 
people use this functionality to `mark release points (v1.0, v2.0 and so on)`. In this tutorial, you’ll learn:
- how to list existing tags
- how to create and delete tags
- what the different types of tags are.

## Listing Your Tags

Listing the existing tags in Git is straightforward. 
```shell
# show all tags
git tag

# show tags with a filter, in below example, the filter is v1.*
git tal -l "v1.*"

# show a specific tag with details
git show v1.8
```
> The option can be `-l` or `--list`
> 
## Creating Tags

Git supports two types of tags: 
- lightweight: A `lightweight tag` is very much like a branch that doesn’t change(it’s just a pointer to a specific commit.)
- annotated: `Annotated tags`, however, are stored as full objects in the Git database. They’re `checksummed`; contain the 
                             tagger name, email, and date; have a tagging message; and can be signed and verified with 
                              GNU Privacy Guard (GPG). It’s generally recommended that you create annotated tags so you 
                            can have all this information; but if you want a temporary tag or for some reason don’t
                             want to keep the other information, lightweight tags are available too.

```shell
# create an annotated tag
git tag -a v1.8 -m "v1.8"

# -a specify the annotation of the tag
# -m specify the tag description. In general, we keep them the same value

```

We can also tag commits after you've moved past them. Suppose your commit history looks like:

```shell
git log --pretty=oneline
15027957951b64cf874c3557a0f3547bd83b3ff6 Merge branch 'experiment'
a6b4c97498bd301d84096da251c98a07c7723e65 Create write support
0d52aaab4479697da7686c15f77a3d64d9165190 One more thing
6d52a271eda8725415634dd79daabbc4d9b6008e Merge branch 'experiment'
0b7434d86859cc7b8c3d5e1dddfed66ff742fcbc Add commit function
4682c3261057305bdd616e23b64b0857d832627b Add todo file
166ae0c4d3f420721acbb115cc33848dfcc2121a Create write support
9fceb02d0ae598e95dc970b74767f19372d61af8 Update rakefile
964f16d36dfccde844893cac5b347e7b3d44abbc Commit the todo
8a5cbc430f1a9c3d00faaeffd07798508422908a Update readme
```

Now, suppose you forgot to tag the project at v1.2, which was at the “Update rakefile” commit. You can add it after 
the fact. To tag that commit, you specify the commit checksum (or part of it) at the end of the command:

```shell
git tag -a v1.2 9fceb02
```

## Sharing Tags

By default, the `git push` command `doesn’t transfer tags to remote servers`. You will have to explicitly push tags to a 
shared server after you have created them. 

```shell
# push a specific tag
git push origin <tagname>

# push all tags which not already in the remote server
git push origin --tags
```

## Deleting tags

### On local repository

To delete a tag on your local repository, you can use the below commands.

```shell
# general form
git tag -d <tagname>

# example
git tag -d v1.8
```

### On remote repository

To delete a tag from any remote servers. There are two common variations for deleting a tag from a remote server.

```shell
# The first variation general form
git push <remote> :refs/tags/<tagname>
# Git read it as the null value before the colon is being pushed to the remote tag name, effectively deleting it.

# The first variation example
git push origin :refs/tags/v1.4-lw

# The second variation is more popular and intuitive
git push origin --delete <tagname>

# example
git push origin --delete v1.8
```

## Checking out Tags

If you want to view the versions of files a tag is pointing to, you can do a git checkout of that tag, although 
this puts your repository `in “detached HEAD” state, which has some ill side effects`:

```shell
$ git checkout v2.0.0
Note: switching to 'v2.0.0'.

You are in 'detached HEAD' state. You can look around, make experimental
changes and commit them, and you can discard any commits you make in this
state without impacting any branches by performing another checkout.
```

> In “detached HEAD” state, if you make changes and then create a commit, the tag will stay the same, but your new 
> commit won’t belong to any branch and will be unreachable, except by the exact commit hash. Thus, if you need to 
> make changes--say you’re fixing a bug on an older version, for instance--you will generally want to create a branch:
>  `git checkout -b version2 v2.0.0`
> If you do this and make a commit, your version2 branch will be slightly different from your v2.0.0 tag since it 
> will move forward with your new changes, so do be careful.