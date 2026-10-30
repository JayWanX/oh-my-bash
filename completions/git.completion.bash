#! bash oh-my-bash.module
# bash completion support for Git.
#
# native-shell fork: deferred load.
#
# Sourcing a git-completion library is the most expensive thing this
# completion does, and a session that never completes a `git` command never
# needs it. The compspec must exist before the first TAB, so the registration
# stays eager and points at a dispatcher; the library itself is sourced the
# first time that dispatcher runs. Registration is a handful of builtin calls,
# so startup pays almost nothing and the library is paid for once, on first
# use.

function _omb_completion_git_register {
  local primary=(-o bashdefault -o default -o nospace -F _omb_completion_git_dispatch)
  local fallback=(-o default -o nospace -F _omb_completion_git_dispatch)
  local command
  for command in git gitk; do
    complete "${primary[@]}" "$command" 2>/dev/null ||
      complete "${fallback[@]}" "$command"
  done
}

# Source the first usable git-completion library found next to the git on
# PATH, else the copy bundled with oh-my-bash. Non-zero when nothing loaded.
function _omb_completion_git_source_library {
  local git_paths path prefix files file
  IFS=$'\n' read -r -d '' -a git_paths <<< "$(type -aP git)"
  # Note: Falling back on /usr (should already be in the array)
  git_paths+=("/usr/bin/git")
  for path in "${git_paths[@]}"; do
    if [[ -L $path ]]; then
      path=$(_omb_util_readlink "$path")
    fi
    # Note: In the case of symbolic link, the true binary name can
    # contain prefix or suffix for architectures and versions.
    path="${path%/*}"
    prefix="${path%/bin}"
    _omb_util_glob_expand files '"$prefix"/share/{bash-completion/completions/git,{,doc/}git-*/contrib/completion/git-completion.bash}'
    for file in "${files[@]}"; do
      if [[ -f $file && -r $file && -s $file ]]; then
        source "$file"
        return
      fi
    done
  done
  source "$OSH/tools/git-completion.bash"
}

# Public hook: completions that WRAP the git library (gh, hub) call this so
# the library is in place before they test for _git. Non-zero when nothing
# could be sourced. Idempotent, safe to call at any time.
function _omb_completion_git_require {
  if _omb_util_function_exists __gitdir; then
    return 0
  fi
  _omb_completion_git_source_library
}

# First TAB on git/gitk: load the library, then hand the current word to the
# wrapper it just installed (`complete -F __git_wrap<x>_main` replaces this
# dispatcher, so later TABs reach that wrapper directly).
function _omb_completion_git_dispatch {
  if ! _omb_completion_git_require; then
    COMPREPLY=()
    return
  fi
  unset -f _omb_completion_git_dispatch
  case ${COMP_WORDS[0]:-} in
  gitk) __git_wrap__gitk_main ;;
  *)    __git_wrap__git_main ;;
  esac
}

function _omb_completion_git_initialize {
  if ! _omb_util_function_exists __gitdir; then
    _omb_completion_git_register
  fi
}
_omb_completion_git_initialize
unset -f _omb_completion_git_initialize _omb_completion_git_register
