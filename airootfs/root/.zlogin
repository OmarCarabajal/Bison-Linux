# fix for screen readers
if grep -Fqa 'accessibility=' /proc/cmdline &> /dev/null; then
    setopt SINGLE_LINE_ZLE
fi

~/.automated_script.sh

print -P "%K{red}  %k%K{green}  %k%K{yellow}  %k%K{blue}  %k%K{magenta}  %k%K{cyan}  %k%K{white}  %k  %K{red}  %k%K{green}  %k%K{yellow}  %k%K{blue}  %k%K{magenta}  %k%K{cyan}  %k%K{white}  %k"

echo -e "\nPara instalar Bison: \e[1;36mbison-install\e[0m"
echo -e "Probar live: \e[1;36mbison-live\e[0m\n"

# Comandos de BISON
install() {
  bison-install
}

live() {
  bison-live
}