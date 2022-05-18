#!/bin/bash

# path:   /home/klassiker/.local/share/repos/fzf/fzf_git_commit.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2022-05-18T16:38:43+0200

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to show/checkout commits for a file or
                                 reset commits for a repository
  Usage:
    $script [--reset] <path/file>

  Settings:
    [--reset] = reset all commits in current repository

  Examples:
    $script <path/file>
    $script --reset"

git_commit() {
    git log --oneline -- "$1" \
        | fzf +s +m -e  \
            --preview "git show --color $(printf "{1}" | cut -d" " -f1)" \
            --preview-window "right:70%" \
        | cut -d" " -f1
}

git_commits_reset() {
    printf "\rDelete all commits in the current respository (YES): " \
        && read -r "key"
    case "$key" in
        YES)
            printf "1) Create orphan branch...\n"
            git checkout --orphan latest_branch

            printf "2) Add all the files and folders...\n"
            git add -A

            printf "3) Commit the changes...\n"
            git commit -am "reset commits"

            printf "4) Delete the master branch...\n"
            git branch -D master

            printf "5) Rename the current branch to master...\n"
            git branch -m master

            printf "6) Force update repository...\n"
            git push -f origin master

            printf "7) Set upstream...\n"
            git push --set-upstream origin master
            ;;
        *)
            printf "No commits deleted...\n"
            exit 0
            ;;
    esac
}

case "$1" in
    -h | --help | "")
        printf "%s\n" "$help"
        ;;
    --reset)
        git_commits_reset
        ;;
    *)
        ! [ -f "$1" ] \
            && exit 1

        commit_id="$(git_commit "$1")"

        [ -n "$commit_id" ] \
            && git checkout "$commit_id" -- "$1"
        ;;
esac
