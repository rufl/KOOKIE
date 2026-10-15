#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v python3 >/dev/null || { echo 'install_kof_lab: python3 is required' >&2; exit 2; }
command -v git >/dev/null || { echo 'install_kof_lab: git is required' >&2; exit 2; }
command -v mvn >/dev/null || { echo 'install_kof_lab: mvn is required' >&2; exit 2; }
command -v java >/dev/null || { echo 'install_kof_lab: java is required' >&2; exit 2; }

repository="${KOOKIE_KOF_REPOSITORY:-https://github.com/KofLang/Kof4j.git}"
latest_commit="$(git ls-remote "$repository" refs/heads/lab | awk 'NF { print $1; exit }')"
[[ "$latest_commit" =~ ^[0-9a-f]{40}$ ]] || {
  echo 'install_kof_lab: refs/heads/lab did not resolve to a commit' >&2
  exit 2
}

work_dir="$(mktemp -d -t kookie-kof-lab-install-XXXXXX)"
cleanup() { rm -rf -- "$work_dir"; }
trap cleanup EXIT INT TERM

git clone --depth 1 --filter=blob:none --branch lab "$repository" "$work_dir/kof" >/dev/null
actual_commit="$(git -C "$work_dir/kof" rev-parse HEAD)"
[[ "$actual_commit" == "$latest_commit" ]] || {
  echo 'install_kof_lab: lab moved during checkout; retry' >&2
  exit 2
}
build_version="$(tr -d '\r\n' < "$work_dir/kof/VERSION")"
[[ "$build_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([+-][0-9A-Za-z.-]+)?$ ]] || {
  echo "install_kof_lab: upstream VERSION is invalid: $build_version" >&2
  exit 2
}

bash "$root_dir/scripts/prepare_kof_source.sh" "$work_dir/kof" "$build_version"
mvn -q -f "$work_dir/kof/pom.xml" flatten:flatten -Drevision="$build_version"
for pom_dir in "$work_dir/kof" "$work_dir/kof/kof-compiler" \
    "$work_dir/kof/kof-cli" "$work_dir/kof/kof-runtime" \
    "$work_dir/kof/kof-script" "$work_dir/kof/kof-c-compiler"; do
  cp -- "$pom_dir/.flattened-pom.xml" "$pom_dir/pom.xml"
done
mvn -q -f "$work_dir/kof/pom.xml" clean package \
  -DskipTests -Drevision="$build_version" \
  -DcreateDependencyReducedPom=false
bash "$work_dir/kof/scripts/package.sh" \
  --output "$work_dir/dist" --skip-build
archive="$work_dir/dist/kof-${build_version}-linux-x86_64.tar.gz"
[[ -f "$archive" ]] || {
  echo "install_kof_lab: missing packaged archive: $archive" >&2
  exit 2
}
archive_sha256="$(sha256sum "$archive" | awk '{ print $1 }')"
latest_after_commit="$(git ls-remote "$repository" refs/heads/lab | awk 'NF { print $1; exit }')"
[[ "$latest_after_commit" == "$latest_commit" ]] || {
  printf 'install_kof_lab: lab advanced during build; built=%s latest=%s; retry\n' \
    "$latest_commit" "$latest_after_commit" >&2
  exit 2
}
KOOKIE_KOF_REPOSITORY="$repository" python3 "$root_dir/scripts/update_kof_lab.py" \
  --apply --expected-commit "$latest_commit" --expected-version "$build_version"
source "$root_dir/scripts/kof_pin.sh"
[[ "$KOF_PIN_SOURCE_COMMIT" == "$latest_commit" &&
  "$KOF_PIN_VERSION" == "$build_version" ]] || {
  echo 'install_kof_lab: tracked pin changed unexpectedly after build' >&2
  exit 2
}

install_parent="${KOOKIE_KOF_INSTALL_PARENT:-$HOME/.local/share/kof4j}"
install_dir="$install_parent/kookie-${build_version}-lab-${latest_commit:0:12}"
staging_dir="$install_parent/.kookie-${build_version}-lab-${latest_commit:0:12}.tmp.$$"
mkdir -p "$install_parent"
rm -rf -- "$staging_dir"
mkdir -p "$staging_dir"
tar -xzf "$archive" -C "$staging_dir"
extracted_dir="$staging_dir/kof-${build_version}-linux-x86_64"
[[ -x "$extracted_dir/bin/kof" ]] || {
  echo 'install_kof_lab: packaged Kof executable is missing' >&2
  exit 2
}
rm -rf -- "$install_dir"
mv -- "$extracted_dir" "$install_dir"
rmdir -- "$staging_dir" 2>/dev/null || true

bin_dir="${KOOKIE_KOF_BIN_DIR:-$HOME/.local/bin}"
mkdir -p "$bin_dir"
ln -sfn "$install_dir/bin/kof" "$bin_dir/kof"
printf 'installed Kof lab: version=%s source=%s archive_sha256=%s path=%s\n' \
  "$build_version" "$latest_commit" "$archive_sha256" "$install_dir"
"$bin_dir/kof" version
