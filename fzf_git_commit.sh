#!/bin/sh

# path:   /home/klassiker/.local/share/repos/fzf/fzf_git_commit.sh
# author: klassiker [mrdotx]
# url:    https://github.com/mrdotx/fzf
# date:   2025-08-09T06:01:11+0200

# speed up script and avoid language problems by using standard c
LC_ALL=C
LANG=C

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to show/checkout commits for files or
                                 reset commits for a repository
  Usage:
    $script [--log/--reset] <path/file> [path/file1] [path/file2]

  Settings:
    [--log]   = show commit logs
    [--reset] = reset all commits in the current repository folder

  Examples:
    $script <path/file>
    $script --log <path/file>
    $script --reset"

git_log() {
    c1="%C(yellow)"
    c2="%C(brightblue)"
    c3="%C(brightmagenta)"
    c4="%C(brightcyan)"
    cr="%C(reset)"

    git log --pretty="$c1%h $c2%cs $c3%G? $c4%an:$cr %s" "$@"
}

git_commit() {
    for entry in "$@"; do
        [ -f "$entry" ] \
            && commit_id=$(git_log "$entry" \
                | fzf +s \
                    --preview-window "up:75%" \
                    --preview "git show --color $(printf "{1}")" \
                | cut -d" " -f1) \
            && [ -n "$commit_id" ] \
                && git checkout "$commit_id" "$entry" \
                && git restore --staged "$entry"
    done
}

git_commit_reset() {
    printf "\rDelete all commits in the current respository folder (YES): " \
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
    --log)
        shift

        git_log "$@"
        ;;
    --reset)
        git_commit_reset
        ;;
    *)
        git_commit "$@"
        ;;
esac
