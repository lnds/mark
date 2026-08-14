# bash completion for mark, a markdown viewer for the terminal.
#
# Kept compatible with bash 3.2, the version macOS still ships: no
# mapfile, no associative arrays, and compopt is called only if it
# exists (it arrived in bash 4).
#
# No option is spelled --opt=value: mark reads a flag's argument as the
# next token only, so `--color=never` reaches it as an unknown option.

_mark() {
    local cur prev ext line
    cur=${COMP_WORDS[COMP_CWORD]}
    prev=${COMP_WORDS[COMP_CWORD-1]}
    COMPREPLY=()

    # A flag expecting a value consumes the next word, whatever it is.
    case $prev in
        -s|--style)
            COMPREPLY=( $(compgen -W 'dark light auto' -- "$cur") )
            return ;;
        --color)
            COMPREPLY=( $(compgen -W 'auto always never' -- "$cur") )
            return ;;
        -w|--width)
            COMPREPLY=( $(compgen -W '60 72 80 100 120' -- "$cur") )
            return ;;
    esac

    if [[ $cur == -* ]]; then
        COMPREPLY=( $(compgen -W '-h --help -v --version -w --width
                                  -s --style --color -p --pager
                                  -P --no-pager' -- "$cur") )
        return
    fi

    # Markdown files alone when the directory has any — a project's
    # README should not come surrounded by its images and scripts —
    # falling back to every file when none match, since mark renders
    # any text it is handed. Directories stay listed either way so the
    # tree remains walkable.
    local -a md dirs
    md=()
    dirs=()

    for ext in md markdown mdown mkd mkdn mdwn text; do
        while IFS= read -r line; do
            [[ -n $line ]] && md[${#md[@]}]=$line
        done < <(compgen -f -X "!*.$ext" -- "$cur")
    done

    while IFS= read -r line; do
        [[ -n $line ]] && dirs[${#dirs[@]}]=$line
    done < <(compgen -d -- "$cur")

    if [[ ${#md[@]} -gt 0 ]]; then
        COMPREPLY=( "${md[@]}" "${dirs[@]}" )
    else
        while IFS= read -r line; do
            [[ -n $line ]] && COMPREPLY[${#COMPREPLY[@]}]=$line
        done < <(compgen -f -- "$cur")
    fi

    # bash 4+ only, and it errors when the function is called outside a
    # real completion (as a test harness does), which is not worth a
    # message either way.
    if type compopt >/dev/null 2>&1; then
        compopt -o filenames 2>/dev/null
    fi
}

complete -F _mark mark
