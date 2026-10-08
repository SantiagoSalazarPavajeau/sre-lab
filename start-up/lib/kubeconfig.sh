# shellcheck shell=bash

# Helper functions to choose the appropriate kubeconfig (host vs internal).
# Usage: source this file and call sre_lab_use_kubeconfig (optionally with
# "host", "internal", or "auto"). Defaults to auto detection.

SRE_LAB_PROJECT_ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SRE_LAB_KUBECONFIG_HOST="${SRE_LAB_PROJECT_ROOT}/.kind-kubeconfig-host"
SRE_LAB_KUBECONFIG_INTERNAL="${SRE_LAB_PROJECT_ROOT}/.kind-kubeconfig-internal"
SRE_LAB_KUBECONFIG_LINK="${SRE_LAB_PROJECT_ROOT}/.kind-kubeconfig"

sre_lab_detect_kubeconfig_variant() {
  local requested="${SRE_LAB_KUBECONFIG_VARIANT:-}"
  case "${requested}" in
    host|internal)
      printf '%s' "${requested}"
      return 0
      ;;
    auto|'')
      :
      ;;
    *)
      printf 'Unknown SRE_LAB_KUBECONFIG_VARIANT="%s". Falling back to auto.\n' "${requested}" >&2
      ;;
  esac

  case "${KIND_USE_INTERNAL:-}" in
    1|true|TRUE|yes|YES|y|Y) printf '%s' internal; return 0 ;;
    0|false|FALSE|no|NO|n|N) printf '%s' host; return 0 ;;
  esac

  if [ -f "/.dockerenv" ] || grep -Eiq '/(docker|containerd|kubepods|lxc)/' /proc/1/cgroup 2>/dev/null; then
    printf '%s' "internal"
  else
    printf '%s' "host"
  fi
}

sre_lab_use_kubeconfig() {
  local variant="${1:-auto}"
  if [ "${variant}" = "auto" ] || [ -z "${variant}" ]; then
    variant="$(sre_lab_detect_kubeconfig_variant)"
  fi

  local source_file
  case "${variant}" in
    host)
      source_file="${SRE_LAB_KUBECONFIG_HOST}"
      ;;
    internal)
      source_file="${SRE_LAB_KUBECONFIG_INTERNAL}"
      ;;
    *)
      printf 'Unsupported kubeconfig variant "%s"\n' "${variant}" >&2
      return 1
      ;;
  esac

  if [ ! -f "${source_file}" ]; then
    printf 'Expected kubeconfig "%s" not found. Run start-up/cluster-up.sh first.\n' "${source_file}" >&2
    return 1
  fi

  # Maintain a predictable symlink for consumers that still read .kind-kubeconfig
  ln -sf "$(basename "${source_file}")" "${SRE_LAB_KUBECONFIG_LINK}"

  export KUBECONFIG="${SRE_LAB_KUBECONFIG_LINK}"
  KUBECONFIG_FILE="${SRE_LAB_KUBECONFIG_LINK}"
  export KUBECONFIG_FILE
  SRE_LAB_KUBECONFIG_ACTIVE_VARIANT="${variant}"
  export SRE_LAB_KUBECONFIG_ACTIVE_VARIANT

  if [ "${SRE_LAB_KUBECONFIG_SILENT:-0}" != "1" ]; then
    printf 'Using %s kubeconfig (%s).\n' "${variant}" "${source_file}"
  fi
}
