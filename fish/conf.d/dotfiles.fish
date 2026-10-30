# Repositório dos dotfiles (bare em ~/.dotfiles, arquivos em ~/.config)
# Uso: dot status | dot add quickshell | dot commit -m "..." | dot push
function dot --wraps git --description 'git dos dotfiles'
    git --git-dir=$HOME/.dotfiles --work-tree=$HOME/.config $argv
end
