# vispat

MYVIM=/usr/bin/vim
if [ -f /etc/redhat-release ] && [ -x /usr/bin/vimx ]; then
    MYVIM=/usr/bin/vimx
fi
if ! $MYVIM -h | grep servername > /dev/null; then
    echo "vispat could not find a vim with server features"
    return
fi

export MYVIM

alias vp=select_vim_pane

# vim_server_name
# determines the name of the vim server that
# we should start or talk to. This will produce
# a string like VIMSERVER.00_01 where 00 is the
# session name and 01 is the number of the current
# window.
function vim_server_name {
    echo $( printf "VIMSERVER.%s_%02d" $( tmux display-message -p '#S' ) $( tmux display-message -p '#I' ) )
}

function v {
    local server=$( vim_server_name )
    local vim_params=(--servername "$server")
    local toggle_pane=1
    local vim_files=()

    # vim tabs require a few extra parameters
    if [[ -n "$vispat_use_tabs" ]]; then
        if [ -n "$( $MYVIM --serverlist | grep -w $server )" ]; then
            vim_params+=(--remote-tab-silent)
        else
            toggle_pane=
            if [ $# -gt 1 ]; then
                vim_params+=(-p)
            fi
        fi
    elif [ -n "$1" ]; then
        vim_params+=(--remote-silent)
    fi

    # If the filename contains "::" or if it starts with a captial letter
    # and does not contain a dot, treat it as the name of a perl module
    # and run mpath to find it.
    local perl_module_pattern="::|(^[A-Z][^.]+$)"
    local git_diff_pattern="^([ab]/)(.+)"

    for arg; do
        if [[ -n "$vispat_for_perl" ]] && [[ "$arg" =~ $perl_module_pattern ]]; then
            local ok
            local file
            file=$( mpath "$arg" )
            ok=$?
            if [ $ok -eq 0 ]; then
                arg="$file"
            fi
        fi

        if [[ "$arg" =~ $git_diff_pattern ]]; then
            arg=${arg#[ab]/}
        fi

        vim_files+=("$arg")
    done

    $MYVIM "${vim_params[@]}" "${vim_files[@]}"

    if [ $toggle_pane ]; then
        select_vim_pane
    fi
}

function select_vim_pane {
    local targetpane=$( tmux list-panes -F '#{pane_current_command} #P' | grep vim | cut -d' ' -f2 )
    if [[ -z "$targetpane" ]]; then
        echo "could not find a pane with a running vim"
    else
        tmux select-pane -t $targetpane
    fi
}

function ws {
    local window=$(tmux display-message -pF '#{window_index}')
    if [[ $( tmux list-panes -t:$window | grep -v active ) ]]; then
        tmux send-keys -t :.+ C-d
    fi

    splitopts="-hdl 50%"
    if [[ $tmuxversion =~ '3[.][0123]' ]]; then
        splitopts="-hdp 50"
    fi
    tmux split-window $splitopts -t:$window
    tmux send-keys -t:$window.1 v Enter
}

sourced=false
if [ -n "$ZSH_EVAL_CONTEXT" ]; then
    case $ZSH_EVAL_CONTEXT in *:file) sourced=true;; esac
elif [ -n "$KSH_VERSION" ]; then
  [ "$(cd $(dirname -- $0) && pwd -P)/$(basename -- $0)" != "$(cd $(dirname -- ${.sh.file}) && pwd -P)/$(basename -- ${.sh.file})" ] && sourced=1
elif [ -n "$BASH_VERSION" ]; then
  (return 0 2>/dev/null) && sourced=true
else # All other shells: examine $0 for known shell binary filenames
  # Detects `sh` and `dash`; add additional shell filenames as needed.
  case ${0##*/} in sh|dash) sourced=true;; esac
fi

if ! $sourced; then
    v "$@"
fi
