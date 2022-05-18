#!/bin/bash

# path:   /home/klassiker/.local/share/repos/fzf/fzf_git_commit.sh
# author: klassiker [mrdotx]
# github: https://github.com/mrdotx/fzf
# date:   2022-05-18T14:01:41+0200

# help
script=$(basename "$0")
help="$script [-h/--help] -- script to show/checkout commits for a file
  Usage:
    $script <path/file>

  Examples:
    $script <path/file>"

git_commit() {
    git log --oneline -- "$1" \
        | fzf +s +m -e  \
            --preview "git show --color $(printf "{1}" | cut -d" " -f1)" \
            --preview-window "right:70%" \
        | cut -d" " -f1
}

case "$1" in
    -h | --help | "")
        printf "%s\n" "$help"
        ;;
    *)
        ! [ -f "$1" ] \
            && exit 1

        commit_id="$(git_commit "$1")"

        [ -n "$commit_id" ] \
            && git checkout "$commit_id" -- "$1"
        ;;
esac
