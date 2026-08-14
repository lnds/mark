# fish completion for mark, a markdown viewer for the terminal.
#
# Unlike zsh, fish has no stock definition claiming the name, and it
# completes files for an unknown command already — so this file adds
# the flags, their values, and a ranking that floats markdown to the
# top, rather than repairing anything.
#
# File completion is deliberately NOT disabled for the command as a
# whole (no bare `complete -c mark -f`): the markdown ranking below is
# an addition, and if it ever stops matching, fish's own file
# completion is still there. Only the value-taking flags are exclusive.
#
# No option is spelled --opt=value: mark reads a flag's argument as the
# next token only, so `--color=never` reaches it as an unknown option.

complete -c mark -s h -l help     -d 'show the help and exit'
complete -c mark -s v -l version  -d 'show the version and exit'
complete -c mark -s p -l pager    -d 'page even when the text fits on screen'
complete -c mark -s P -l no-pager -d 'dump everything at once, without paging'

# -x is -r -f: takes an argument, and no filenames are offered for it.
complete -c mark -s w -l width -x -a '60 72 80 100 120' \
    -d 'output width in columns'

complete -c mark -s s -l style -x -a dark  -d 'for a dark background'
complete -c mark -s s -l style -x -a light -d 'for a light background'
complete -c mark -s s -l style -x -a auto  -d 'decide from the terminal'

complete -c mark -l color -x -a auto   -d 'on for a terminal, off for a pipe or a file'
complete -c mark -l color -x -a always -d 'force colour even when piped'
complete -c mark -l color -x -a never  -d 'plain text (NO_COLOR does the same)'

# -k keeps these ahead of the file completion fish adds on its own, so
# a directory's markdown sorts above its images and scripts without
# hiding them.
complete -c mark -k -a '(__fish_mark_documents)' -d 'markdown file'

function __fish_mark_documents -d 'markdown files in the current token'
    for ext in md markdown mdown mkd mkdn mdwn text
        __fish_complete_suffix ".$ext"
    end
end
