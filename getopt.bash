# shellcheck shell=bash
#
# Forked from https://gist.github.com/dimo414/93776b78a38791ed1bd1bad082d08009
#
# Helper utility to simplify using Bash's getopts utility, and make it usable with functions.
#
# Example usage:
# foo() {
#   local _usage=...                # optional usage string
#   eval "$(parse_opts 'ab:f:v')"   # provide a standard getopts optstring
#   echo "f is $f"                  # opts are now local variables
#   if (( a )); then                # check boolean flags with (( ... ))
#     echo "Saw -a"
#   fi
#   echo "$@"                       # opts are removed from $@, positional args remain
# }
#
# This script eliminates the gruntwork and verbosity of using getopts, allowing you to
# focus on actual behavior rather than argument parsing. It handles looping over getopts,
# parsing each result, and reporting errors. Each parsed option is set as a local variable
# in the calling function, enabling easy and safe access to all values.
#
# No-arg options are set to 0 by default and 1 if passed as an argument, allowing concise
# testing with (( ... )).
#
# Options that accept an argument are set to the empty string by default, and otherwise
# set to the value passed as an argument. To check if a (non-empty) argument was passed
# use [[ -n "$..." ]].
#
# Numeric options, such as -0 which is often used to configure NUL-byte delimited output,
# are also supported but are prefixed with "o" to distinguish from the positional arguments.
#
# All parsed arguments are shift-ed out of $@, leaving any subsequent positional arguments
# in-place. A -- argument can be used to halt option parsing early, e.g. `-a -- -b` will
# only parse -a and leave -b as an argument.
#
# parse_opts takes two optional arguments, min_args and max_args, which constrain the
# number of positional arguments. For example `eval $(parse_opts '...' 2 4)` requires at
# least two but no more than four positional args.
#
# Parsing errors cause the calling function to return with exit code 2. If a _usage
# variable is in scope its contents will be included in the error message.
#


# The output of this function is intended to be passed to eval, therefore we try to
# minimize what it prints and delegate most of the heavy lifting to a separate function.
# Expected output:
#   local OPTIND=1 a b c=0 # vars are dynamically parsed
#   _parse_opts_helper a:b:c 0 '' "$@" || return
#   shift $((OPTIND - 1)); OPTIND=1
parse_opts() {
  local i char last_char var vars=() optstring=${1:-} min_args=${2:-0} max_args=${3:-}
  optstring="${optstring#:}" # ensure string is not prefixed with :
  if ! [[ "$optstring" =~ ^[a-zA-Z0-9:]*$ ]] || [[ "$optstring" == *::* ]]; then
    echo "Invalid optstring: $optstring" >&2
    echo 'return 2' # for eval-ing
    return 2
  fi
  for (( i=${#optstring}-1 ; i >= 0 ; i-- )); do
    char=${optstring:i:1}
    if [[ "$char" != ":" ]]; then
      var="$char"
      if [[ "$var" =~ [0-9] ]]; then
        # prefix with 'o' so numeric flags aren't confused for positional args
        var="o${var}"
      fi
      if [[ "$last_char" == ":" ]]; then
        vars+=("$var")
      else
        vars+=("${var}=0")
      fi
    fi
    last_char=$char
  done
  # Do as little work as possible here, as it will be eval-ed by the caller.
  echo "local OPTIND=1 ${vars[*]}"
  printf '_parse_opts_helper %q %q %q "$@" || return\n' "$optstring" "$min_args" "$max_args"
  # shellcheck disable=SC2016
  echo 'shift $((OPTIND - 1)); OPTIND=1'
}

# Actual parser implementation; assumes all variables it sets are local,
# which parse_opts sets up. Do not call directly.
_parse_opts_helper() {
  local OPTARG opt failed=0
  # $1 and $3 can be empty strings, so ? instead of :?
  local optstring=${1?optstring} min_args=${2:?min_args} max_args=${3?max_args}
  shift 3
  # ensure optstring _is_ prefixed with :
  while getopts ":${optstring#:}" opt; do
    case "${opt}" in
      [?:])
        case "${opt}" in
          :) echo "Option '-${OPTARG}' requires an argument" >&2 ;;
          [?]) echo "Unknown option '-${OPTARG}'" >&2 ;;
        esac
        failed=1
        break
        ;;
      *)
        if [[ "$optstring" != *"${opt}:"* ]]; then
          OPTARG=1
        fi
        if [[ "$opt" =~ [0-9] ]]; then
          opt="o${opt}"
        fi
        printf -v "$opt" '%s' "$OPTARG"
        ;;
    esac
  done
  local pos_args=$(( $# - OPTIND + 1 ))
  if (( pos_args < min_args )); then
    echo "Insufficient arguments; minimum ${min_args}" >&2
    failed=1
  elif [[ -n "$max_args" ]] && (( pos_args > max_args )); then
    echo "Too many arguments; maximum ${max_args}" >&2
    failed=1
  fi
  if (( failed )); then
    if [[ -n "${_usage:-}" ]]; then
      echo "Usage: $_usage" >&2
    fi
    return 2
  fi
}
