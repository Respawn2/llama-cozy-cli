# fish completions for llama-cozy (ai / ailist)

function __ai_models
    command ai list --names 2>/dev/null
end

complete -c ai -f
complete -c ai -n __fish_use_subcommand -a run     -d 'Chat with a model'
complete -c ai -n __fish_use_subcommand -a list    -d 'List local models'
complete -c ai -n __fish_use_subcommand -a serve   -d 'Start OpenAI-compatible server'
complete -c ai -n __fish_use_subcommand -a pull    -d 'Download a GGUF from Hugging Face'
complete -c ai -n __fish_use_subcommand -a rm      -d 'Delete a model'
complete -c ai -n __fish_use_subcommand -a bench   -d 'Benchmark a model'
complete -c ai -n __fish_use_subcommand -a doctor  -d 'Check the setup'
complete -c ai -n __fish_use_subcommand -a config  -d 'Show or change settings'
complete -c ai -n __fish_use_subcommand -a help    -d 'Show help'
complete -c ai -n __fish_use_subcommand -a '(__ai_models)' -d 'Model'

complete -c ai -n '__fish_seen_subcommand_from run chat serve rm remove bench' -a '(__ai_models)' -d 'Model'
complete -c ai -n '__fish_seen_subcommand_from run chat serve' -s c -l ctx -x -d 'Context size'
complete -c ai -n '__fish_seen_subcommand_from run chat' -s s -l system -x -d 'System prompt'
complete -c ai -n '__fish_seen_subcommand_from run chat' -s p -l prompt -x -d 'One-shot prompt'
complete -c ai -n '__fish_seen_subcommand_from run chat serve' -l cpu -d 'No GPU offload'
complete -c ai -n '__fish_seen_subcommand_from serve' -l port -x -d 'Port'
complete -c ai -n '__fish_seen_subcommand_from serve' -l host -x -d 'Host'
complete -c ai -n '__fish_seen_subcommand_from rm remove' -s y -l yes -d 'No confirmation'

complete -c ai -n '__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from show path edit get set' -a 'show path edit get set'
complete -c ai -n '__fish_seen_subcommand_from get set' -a 'MODELS_DIR SYSTEM_PROMPT CTX GPU_LAYERS HOST PORT BIN_DIR EXTRA_ARGS'

complete -c ailist -f -a '--names --paths'
