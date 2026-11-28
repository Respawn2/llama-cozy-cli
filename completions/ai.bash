# bash completions for llama-cozy (ai / ailist)

_ai_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local IFS=$'\n'
    local cmds=$'run\nlist\nserve\npull\nrm\nbench\ndoctor\nconfig\nhelp'
    local models; models=$(command ai list --names 2>/dev/null)

    if [ "$COMP_CWORD" -eq 1 ]; then
        COMPREPLY=($(compgen -W "$cmds"$'\n'"$models" -- "$cur"))
        return
    fi
    case ${COMP_WORDS[1]} in
        run|chat|serve|rm|remove|bench)
            if [[ $cur == -* ]]; then
                COMPREPLY=($(compgen -W $'--ctx\n--system\n--prompt\n--cpu\n--port\n--host\n--yes' -- "$cur"))
            else
                COMPREPLY=($(compgen -W "$models" -- "$cur"))
            fi ;;
        config)
            if [ "$COMP_CWORD" -eq 2 ]; then
                COMPREPLY=($(compgen -W $'show\npath\nedit\nget\nset' -- "$cur"))
            else
                COMPREPLY=($(compgen -W $'MODELS_DIR\nSYSTEM_PROMPT\nCTX\nGPU_LAYERS\nHOST\nPORT\nBIN_DIR\nEXTRA_ARGS' -- "$cur"))
            fi ;;
    esac
}
complete -F _ai_complete ai
