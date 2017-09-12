#!/bin/bash

_gitkeep()
{
    local cur prev opts for_mer
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts=("forward_merge clean setup")
    for_mer="forward_merge"


    case "${COMP_WORDS[1]}" in
        forward_merge)
            if [ "${COMP_WORDS[COMP_CWORD-1]}" == "--base_branch" ] ; then
              local running=$(for x in `./gitkeep forward_merge --output_local`; do echo ${x} ; done)
              COMPREPLY=( $(compgen -W "${running}" -- ${cur}) )
            elif [ "${COMP_WORDS[COMP_CWORD-1]}" == "--merge_branch" ] ; then
              local running=$(for x in `./gitkeep forward_merge --output_remote`; do echo ${x} ; done)
              COMPREPLY=( $(compgen -W "${running}" -- ${cur}) )
            else
              local running=$(for x in `./gitkeep forward_merge -c`; do echo ${x} ; done)
              COMPREPLY=( $(compgen -W "${running}" -- ${cur}) )
            fi            
            return 0
            ;;
        clean)
            local running=$(for x in `./gitkeep clean -c`; do echo ${x} ; done)
            COMPREPLY=( $(compgen -W "${running}" -- ${cur}) )
            return 0
            ;;
        setup)
           return 0
           ;;
        *)
        ;;
    esac


    COMPREPLY=( $(compgen -W "${opts}" ${cur}) )
    return 0
}
echo "loaded git script"
complete -F _gitkeep gitkeep
