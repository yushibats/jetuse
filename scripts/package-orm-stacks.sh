#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-${repo_root}/dist/orm}"

mkdir -p "${output_dir}"
output_dir="$(cd "${output_dir}" && pwd)"

if [[ ! -f "${repo_root}/packages/web/dist/index.html" ]]; then
  echo "packages/web/dist/index.html is missing; build the SPA before packaging" >&2
  exit 1
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/jetuse-orm-packages.XXXXXX")"
trap 'rm -rf "${work_dir}"' EXIT

source_tree="${work_dir}/source"
mkdir -p "${source_tree}"

# Copy only tracked Terraform files. PACKAGE_FROM_WORKTREE=1 is reserved for
# local/CI inspection so a not-yet-committed v2 can be checked before release.
if [[ "${PACKAGE_FROM_WORKTREE:-0}" == "1" ]]; then
  echo "[package] 作業ツリーから梱包します（検査用。配布には使わないこと）" >&2
  git -C "${repo_root}" ls-files --cached --others --exclude-standard --deduplicate \
    -- infra/orm infra/orm-v2-admin infra/orm-v2-compartment infra/terraform/modules \
    | (cd "${repo_root}" && while IFS= read -r file; do [ -f "${file}" ] && printf '%s\n' "${file}"; done) \
    | tar -cf - -C "${repo_root}" -T - \
    | tar -xf - -C "${source_tree}"
else
  git -C "${repo_root}" archive --format=tar HEAD \
    infra/orm \
    infra/orm-v2-admin \
    infra/orm-v2-compartment \
    infra/terraform/modules \
    | tar -xf - -C "${source_tree}"
fi

rewrite() { # rewrite <file> <sed-expr>
  sed "$2" "$1" >"$1.tmp" && mv "$1.tmp" "$1"
}

package_stack() { # package_stack <source-directory-name> <archive-base-name>
  local stack_name="$1"
  local archive_name="$2"
  local app_stage="${work_dir}/${archive_name}"

  mkdir -p "${app_stage}"
  cp -R "${source_tree}/infra/${stack_name}/." "${app_stage}/"
  mkdir -p "${app_stage}/terraform" "${app_stage}/packages/web"
  cp -R "${source_tree}/infra/terraform/modules" "${app_stage}/terraform/"
  cp -R "${repo_root}/packages/web/dist" "${app_stage}/packages/web/"

  # Resource Manager runs Terraform from the ZIP root. Keep the rewrite portable
  # across GNU and BSD sed by using a temporary file instead of sed -i.
  rewrite "${app_stage}/main.tf" 's#../terraform/modules/#./terraform/modules/#g'
  rewrite "${app_stage}/main.tf" 's#${path.module}/../../packages/web/dist#${path.module}/packages/web/dist#g'
  if [[ -f "${app_stage}/spa.tf" ]]; then
    rewrite "${app_stage}/spa.tf" 's#${path.module}/../../packages/web/dist#${path.module}/packages/web/dist#g'
  fi

  # Release archives use immutable image tags shared by the API, Functions and agents.
  if [[ -n "${GITHUB_SHA:-}" ]]; then
    rewrite "${app_stage}/variables.tf" \
      "/^variable \"image_tag\"/,/^}/ s|^  default     = \"latest\"$|  default     = \"${GITHUB_SHA}\"|"
    rewrite "${app_stage}/schema.yaml" \
      "/^  image_tag:/,/^$/ s|^    default: \"latest\"$|    default: \"${GITHUB_SHA}\"|"
    if ! grep -q "default     = \"${GITHUB_SHA}\"" "${app_stage}/variables.tf" \
      || ! grep -q "default: \"${GITHUB_SHA}\"" "${app_stage}/schema.yaml"; then
      echo "failed to pin ${archive_name} image_tag to ${GITHUB_SHA}" >&2
      exit 1
    fi
  fi

  if find "${app_stage}" -type d -name .terraform -print -quit | grep -q .; then
    echo "unexpected .terraform directory in ${app_stage}" >&2
    exit 1
  fi
  if grep -R -n -E \
    'source[[:space:]]*=[[:space:]]*"\.\./terraform/modules|spa_dist_dir[[:space:]]*=.*\.\./\.\./packages/web/dist' \
    "${app_stage}"; then
    echo "repository-relative path remains in ${app_stage}" >&2
    exit 1
  fi

  (cd "${app_stage}" && zip -q -r "${work_dir}/${archive_name}.zip" .)
  install -m 0644 "${work_dir}/${archive_name}.zip" "${output_dir}/${archive_name}.zip"
  echo "Created ${output_dir}/${archive_name}.zip"
}

package_stack "orm" "jetuse-orm"
package_stack "orm-v2-admin" "jetuse-orm-admin"
package_stack "orm-v2-compartment" "jetuse-orm-compartment"
