ZSH_THEME_GIT_PROMPT_PREFIX=" on %F{green}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f"
ZSH_THEME_GIT_PROMPT_DIRTY=""
ZSH_THEME_GIT_PROMPT_CLEAN=""
ZSH_THEME_GIT_PROMPT_ADDED="%F{green} ✚%f"
ZSH_THEME_GIT_PROMPT_MODIFIED="%F{blue} ✹%f"
ZSH_THEME_GIT_PROMPT_DELETED="%F{red} ✖%f"
ZSH_THEME_GIT_PROMPT_RENAMED="%F{magenta} ➜%f"
ZSH_THEME_GIT_PROMPT_UNMERGED="%F{yellow} ═%f"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%F{cyan} ✭%f"

# ============================================================
# Git Prompt
# ============================================================

function dotfiles_git_refresh() {
    DF_GIT_PROMPT=""

    # No hacer nada si Git no está disponible.
    (( $+commands[git] )) || return 0

    # --------------------------------------------------------
    # State
    # --------------------------------------------------------

    local report
    local line
    local xy

    local branch=""
    local flags=""

    local ahead=0
    local behind=0
    local stashes=0

    local added=0
    local modified=0
    local deleted=0
    local renamed=0
    local conflict=0
    local untracked=0

    # --------------------------------------------------------
    # Repository Status
    # --------------------------------------------------------

    # Una sola consulta local.
    #
    # No realiza:
    #   - fetch
    #   - pull
    #   - llamadas a GitHub
    #
    # GIT_OPTIONAL_LOCKS evita bloquear innecesariamente el repo.

    report=$(
        GIT_OPTIONAL_LOCKS=0 \
        command git status \
            --porcelain=v2 \
            --branch \
            --show-stash \
            2>/dev/null
    ) || return 0

    # --------------------------------------------------------
    # Parse Git Status
    # --------------------------------------------------------

    for line in "${(@f)report}"; do

        case "$line" in

            '# branch.head '*)
                branch=${line#\# branch.head }
                ;;

            '# branch.oid '*)
                if [[ "$branch" == "(detached)" ]]; then
                    branch="@${${line#\# branch.oid }[1,8]}"
                fi
                ;;

            '# branch.ab '*)
                local counts=(${=line})

                ahead=${counts[3]#+}
                behind=${counts[4]#-}
                ;;

            '# stash '*)
                stashes=${line#\# stash }
                ;;

            '? '*)
                untracked=1
                ;;

            'u '*)
                conflict=1
                ;;

            [12]' '*)
                xy=${line[3,4]}

                [[ "$xy" == *A* ]] && added=1
                [[ "$xy" == *M* ]] && modified=1
                [[ "$xy" == *D* ]] && deleted=1
                [[ "$xy" == *R* ]] && renamed=1
                ;;

        esac

    done


    # --------------------------------------------------------
    # Detached HEAD
    # --------------------------------------------------------

    if [[ "$branch" == "(detached)" ]]; then
        branch="@$(command git rev-parse --short HEAD 2>/dev/null)"
    fi


    # --------------------------------------------------------
    # Prompt Safety
    # --------------------------------------------------------

    branch=${branch//\%/%%}


    # --------------------------------------------------------
    # Working Tree Flags
    # --------------------------------------------------------

    (( added )) && flags+="$ZSH_THEME_GIT_PROMPT_ADDED"

    (( modified )) && flags+="$ZSH_THEME_GIT_PROMPT_MODIFIED"

    (( deleted )) && flags+="$ZSH_THEME_GIT_PROMPT_DELETED"

    (( renamed )) && flags+="$ZSH_THEME_GIT_PROMPT_RENAMED"

    (( conflict )) && flags+="$ZSH_THEME_GIT_PROMPT_UNMERGED"

    (( untracked )) && flags+="$ZSH_THEME_GIT_PROMPT_UNTRACKED"


    # --------------------------------------------------------
    # Remote / Stash State
    # --------------------------------------------------------

    (( ahead )) && flags+=" %F{green}⇡$ahead%f"

    (( behind )) && flags+=" %F{red}⇣$behind%f"

    (( stashes )) && flags+=" %F{yellow}󰏗 $stashes%f"


    # --------------------------------------------------------
    # Final Git Prompt
    # --------------------------------------------------------

    DF_GIT_PROMPT="%F{magenta}[%f \
%F{cyan}%f\
${ZSH_THEME_GIT_PROMPT_PREFIX}\
$branch\
${ZSH_THEME_GIT_PROMPT_SUFFIX}\
$flags \
%F{magenta}]%f\
%F{red}──╯%f"

    return 0
}
