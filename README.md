# dotfiles

Meu rice de Hyprland no CachyOS, baseado no [illogical-impulse](https://github.com/end-4/dots-hyprland) do end-4 (shell em Quickshell, Material 3 com cores tiradas do wallpaper).

## O que tem de diferente do ii original

| | |
|---|---|
| **Barra em 3 ilhas** | Pílulas flutuantes (esquerda / meio / direita). `bar.islands` no `config.json` |
| **Player de música** | Busca e toca do YouTube (yt-dlp + mpv), fila, favoritos, capa com disco de vinil girando e ondas do cava. Também controla Spotify/navegador via MPRIS |
| **Cava na área de trabalho** | Barras na base da tela, atrás das janelas, só enquanto toca música. `background.widgets.visualizer` |
| **Relógio-card** | `09:04 │ OUTUBRO 27 Terça` na área de trabalho. `background.widgets.clock.style: "card"` |
| **Menu de energia em pílula** | Desce de baixo da barra; Sair/Reiniciar/Desligar pedem confirmação |
| **Troca automática de wallpaper** | A cada N minutos, sem repetir até passar por todos. `background.autoChange` |
| **Minimizar de verdade** | Super+H esconde a janela; ícones dos minimizados na barra |
| **Pendrives na barra** | Ícone com Montar / Abrir / Ejetar |
| **Calendário** | Clique no relógio da barra |

## Instalação

1. Instale o [illogical-impulse](https://github.com/end-4/dots-hyprland) normalmente.
2. Copie as pastas deste repositório para `~/.config/` (faça backup das suas antes).
3. Dependências extras do player: `sudo pacman -S yt-dlp mpv-mpris cava socat`
4. Atalhos (em `~/.config/hypr/custom/keybinds.lua`, que não faz parte deste repositório):

```lua
hl.unbind("SUPER + M")
hl.bind("SUPER + M", hl.dsp.global("quickshell:musicPlayerToggle"), {description = "Shell: Music player"})
hl.bind("SUPER + Escape", hl.dsp.global("quickshell:powerPillToggle"), {description = "Shell: Power menu (pill)"})
hl.bind("SUPER + H", hl.dsp.global("quickshell:minimizeToggle"), {description = "Window: Minimize / restore"})
hl.bind("SUPER + SHIFT + H", hl.dsp.global("quickshell:minimizeRestoreLast"), {description = "Window: Restore last minimized"})
```

## Atalhos

| Tecla | Ação |
|---|---|
| Super+M | Player de música |
| Super+Esc | Menu de energia em pílula |
| Ctrl+Alt+Del | Menu de sessão completo |
| Ctrl+Super+T | Escolher wallpaper |
| Super+H / Super+Shift+H | Minimizar / restaurar |

## Créditos e licença

- Shell [illogical-impulse](https://github.com/end-4/dots-hyprland) por [end-4](https://github.com/end-4) e colaboradores — GPL-3.0.
- Visual do player e da barra inspirado num rice postado no r/hyprland.
- As modificações também são distribuídas sob a [GPL-3.0](LICENSE).
