# "soft" theme for fish's built-in syntax highlighting — managed by cli-setup
# The same muted pastels as the zsh theme and the Starship prompt. No background blocks, no bold.
#   afd75f green · 87afd7 blue · 87d7d7 teal · d787d7 pink · d7af87 tan · ffaf5f orange · d75f5f red

set -g fish_color_normal normal
set -g fish_color_command afd75f
set -g fish_color_keyword d787d7
set -g fish_color_param normal
set -g fish_color_option 87d7d7
set -g fish_color_quote d7af87
set -g fish_color_redirection 8a8a8a
set -g fish_color_end 8a8a8a
set -g fish_color_operator ffaf5f
set -g fish_color_escape 87d7d7
set -g fish_color_comment 6c6c6c --italics
set -g fish_color_error d75f5f
set -g fish_color_valid_path 87afd7
set -g fish_color_search_match --background=3a3a3a
set -g fish_color_selection --background=444444

set -g fish_pager_color_prefix 87afd7
set -g fish_pager_color_completion normal
set -g fish_pager_color_description 8a8a8a
set -g fish_pager_color_progress 8a8a8a
set -g fish_pager_color_selected_background --background=303030
