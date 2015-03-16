# vispat

MYVIM=/usr/bin/vim
if [ -f /etc/redhat-release ] && [ -x /usr/bin/vimx ]; then
    MYVIM=/usr/bin/vimx
fi
if ! $MYVIM -h | grep servername >> /dev/null; then
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
function vim_server_name() {
    local window=$( printf "%02d_%02d" $( tmux display-message -p '#S' ) $( tmux display-message -p '#I' ) )
    local server="VIMSERVER.$window"
    echo $server
}

function v() {
    local server=$( vim_server_name )
    local params="--servername $server"
    local toggle_pane=1

    # vim tabs require a few extra parameters
    if [[ -n "$vispat_use_tabs" ]]; then
        if [ -n "$( $MYVIM --serverlist | grep -w $server )" ]; then
            params="$params --remote-tab-silent"
        else
            toggle_pane=
            if [ $# -gt 1 ]; then
                params="$params -p"
            fi
        fi
    fi

    # If the filename contains "::", treat it as a perl module
    # and run mpath to find it.
    # TODO: Make this work for more than just the first file
    if [[ -n "$vispat_for_perl" ]] && [[ $1 == *::* ]]; then
        file=$( mpath "$1" )
        params="$params $file"
    else
        params="$params $@"
    fi

    $MYVIM $params

    if [ $toggle_pane ]; then
        select_vim_pane
    fi
}

function select_vim_pane() {
    local targetpane=$( tmux list-panes -F '#{pane_current_command} #P' | grep vim | cut -d' ' -f2 )
    if [ "x$targetpane" == "x" ]; then
        echo "could not find a pane with a running vim"
    else
        tmux select-pane -t $targetpane
    fi
}

function ws() {
    if [[ $( tmux list-pane | grep -v active ) ]]; then
        tmux send-keys -t :.+ C-d
        sleep 1
    fi

    tmux split-window -hdp 50
    tmux send-keys -t :.+ v Enter
}

