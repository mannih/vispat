# nvispat

MYVIM=/usr/bin/nvim

alias vp=select_vim_pane

# nvim_listen_address
# determines the socket used by nvim.
# This will produce a path like
# /tmp/VIMSERVER.00_01 where 00 is the
# tmux session name and 01 is the
# number of the current tmux window.

function nvim_listen_address {
    echo $( printf "/tmp/VIMSERVER.%s_%02d" "$( tmux display-message -p '#S' )" "$( tmux display-message -p '#I' )" )
}

function v {
    export NVIM_LISTEN_ADDRESS=$( nvim_listen_address )
    local toggle_pane=true
    local vim_params=()

    # vim tabs require a few extra parameters
    if [[ -n "$vispat_use_tabs" ]]; then
        if [ -n "$( nvr --serverlist | grep -w $( nvim_listen_address ) )" ]; then
            vim_params+=(--remote-tab-silent)
            MYVIM=nvr
        else
            toggle_pane=false
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
            local file=$( mpath "$arg" )
            local ok=$?
            if [ $ok -eq 0 ]; then
                arg="$file"
            fi
        fi

        if [[ "$arg" =~ $git_diff_pattern ]]; then
            arg=${arg#[ab]/}
        fi

        vim_params+=("$arg")
    done

    $MYVIM ${vim_params[@]}

    if $toggle_pane; then
        select_vim_pane
    fi
}

function select_vim_pane {
    local targetpane=$( tmux list-panes -F '#{pane_current_command} #P' | grep vim | cut -d' ' -f2 )
    if [[ -z "$targetpane" ]]; then
        echo "could not find a pane with a running nvim"
    else
        tmux select-pane -t $targetpane
    fi
}

function ws {
    local window=$(tmux display-message -pF '#{window_index}')
    if [[ $( tmux list-panes -t:$window | grep -v active ) ]]; then
        tmux send-keys -t :.+ C-d
    fi

    tmux split-window -hdp 50 -t:$window
    tmux send-keys -t:$window.1 v Enter
}
