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
    echo $( printf "VIMSERVER.%s_%02d" $( tmux display-message -p '#S' ) $( tmux display-message -p '#I' ) )
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

    # If the filename contains "::" or if it starts with a captial letter
    # and does not contain a dot, treat it as the name of a perl module
    # and run mpath to find it.
    if [[ -n "$vispat_for_perl" ]]; then
        local module_pattern="::|(^[A-Z][^.]+$)"
        for param in $@; do
            if [[ "$param" =~ $module_pattern ]]; then
                file=$( mpath "$param" )
                params="$params $file"
            else
                params="$params $param"
            fi
        done
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
    local window=$(tmux display-message -pF '#{window_index}')
    if [[ $( tmux list-panes -t:$window | grep -v active ) ]]; then
        tmux send-keys -t :.+ C-d
    fi

    tmux split-window -hdp 50 -t:$window
    tmux send-keys -t:$window.1 v Enter
}

