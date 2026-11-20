# fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

~/.automated_script.sh

source /usr/local/lib/bison-install/show_bison_menu.zsh

show_bison_menu