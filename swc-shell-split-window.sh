#!/bin/bash
#
# Create terminal for Software Carpentry lesson
# with the log of the commands at the top.

# Session name.  Defaults to 'swc', but you can override from the
# calling process.
SESSION=$1
echo "my session is ${SESSION}"
SESSION="${SESSION:-swc}"

# Where we'll store the executed history.  Defaults to /tmp/log-file,
# but you can override from the calling process.  For example:
#
#   LOG_FILE=/tmp/my-log ./swc-shell-split-window.sh
LOG_FILE="${LOG_FILE:-/tmp/log-file_${SESSION}}"

# The number of lines of history to show.  Defaults to 5, but you can
# override from the calling process.
HISTORY_LINES="${HISTORY_LINES:-5}"


# If $LOG_FILE exists, truncate it, otherwise create it.
# Either way, this leaves us with an empty $LOG_FILE for tailing.
> "${LOG_FILE}"

# Create the session to be used
# * don't attach yet (-d)
# * name it $SESSION (-s "${SESSION}")
# * start reading the log
tmux new-session -d -s "${SESSION}" "tail -f '${LOG_FILE}'"

# Get the unique (and permanent) ID for the new window
WINDOW=$(tmux list-windows -F '#{window_id}' -t "${SESSION}")

# Get the unique (and permanent) ID for the log pane
LOG_PANE=$(tmux list-panes -F '#{pane_id}' -t "${WINDOW}")
LOG_PID=$(tmux list-panes -F '#{pane_pid}' -t "${WINDOW}")

# Split the log-pane (-t "${LOG_PANE}") vertically (-v)
# * make the new pane the current pane (no -d)
# * load history from the empty $LOG_FILE (HISTFILE='${LOG_FILE}')
# * lines which begin with a space character are not saved in the
#   history list (HISTCONTROL=ignorespace)
# * append new history to $HISTFILE after each command
#   (PROMPT_COMMAND='history -a')
# * launch Bash since POSIX doesn't specify shell history or HISTFILE
#   (bash)
# * when the Bash process exits, kill the log process
tmux split-window -v -t "${LOG_PANE}" \
	"HISTFILE='${LOG_FILE}' HISTCONTROL=ignorespace PROMPT_COMMAND='history -a' bash --norc; kill '${LOG_PID}'"

# Get the unique (and permanent) ID for the shell pane
SHELL_PANE=$(tmux list-panes -F '#{pane_id}' -t "${WINDOW}" |
	grep -v "^${LOG_PANE}\$")

tmux send-keys -t "${SHELL_PANE}" " cd" enter

# Unset all aliases to keep your environment from diverging from the
# learner's environment.
tmux send-keys -t "${SHELL_PANE}" " unalias -a" enter

# Set nice prompt displaying
# with cyan
# the command number and
# the '$'.
# Choose your preferred colour with:
# while [ $color -lt 245 ]; do
#     >     echo -e "$color: \\033[38;5;${color}mhello\\033[48;5;${color}mworld\\033[0m"
#     >     ((color++));
#     > done
echo $SESSION
if [[ "${SESSION}" == "swc" ]]; then
    COLOR="5" # Purple
else
    COLOR="227" # Yellow (good with solarized dark)
fi


tmux send-keys -t "${SHELL_PANE}" " export PS1=\"\[\033[38;5;${COLOR}m\]\! $\[\033[0m\] \"" enter

# Clear the history so it starts over at number 1.
# The script shouldn't run any more non-shell commands in the shell
# pane after this.
tmux send-keys -t "${SHELL_PANE}" "history -c" enter

# Send Bash the clear-screen command (see clear-screen in bash(1))
tmux send-keys -t "${SHELL_PANE}" "C-l"

# Wait for Bash to act on the clear-screen.  We need to push the
# earlier commands into tmux's scrollback before we can ask tmux to
# clear them out.
sleep 0.1

# Clear tmux's scrollback buffer so it matches Bash's just-cleared
# history.
tmux clear-history -t "${SHELL_PANE}"

# Need add an additional line because Bash writes a trailing newline
# to the log file after each command, tail reads through that trailing
# newline and flushes everything it read to its pane.
LOG_PANE_HEIGHT=$((${HISTORY_LINES} + 1))

# Resize the log window to show the desired number of lines
tmux resize-pane -t "${LOG_PANE}" -y "${LOG_PANE_HEIGHT}"

# Turn off tmux's status bar, because learners won't have one in their
# terminal.
# * don't print output to the terminal (-q)
# * set this option at the window level (-w).  I'd like new windows in
#   this session to get status bars, but it doesn't seem like there
#   are per-window settings for 'status'.  In any case, the -w doesn't
#   seem to cause any harm.
tmux set-option -t "${WINDOW}" -q -w status off

tmux attach-session -t "${SESSION}"
