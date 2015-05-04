#!/bin/bash

# Script that removes Firefox language ebuilds and creates new ones, usually
# for a new version.

#   Copyright 2014 Sławomir Nizio
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

# The scripts needs to be run within www-client in the overlay; the repository
# must not have uncommitted changes.

# The script asks interactively for a few parameters:
# - list of languages (MOZ_LANGS in Firefox ebuild),
# - new version,
# - location of the Manifest for Firefox - used as the trick that allows to bump
#   the packages without downloading the language packs themselves, and adds
#   correctness to the process (if not security).

e() {
	echo "$*" >&2
	exit 1
}

print_ebuild() {
	local ver=$1

	cat <<-END
	# Copyright 1999-2014 Gentoo Foundation
	# Distributed under the terms of the GNU General Public License v2
	# \$Header: \$

	EAPI=4
	inherit firefox-l10n
END
}

create_ebuild() {
	local lang=$1 package_name_prefix=$2 ver=$3
	[[ $# -ne 3 ]] && e "create_ebuild: expected 3 arguments"

	# firefox-l10n-pl-17.0.1-r1.ebuild
	local package_name="${package_name_prefix}-${lang}"
	local ebuild_name=${package_name}-${ver}.ebuild

	echo "=> ${lang} (${ebuild_name})"

	mkdir "${package_name}" || e "mkdir failed"
	print_ebuild "${ver}" > "${package_name}/${ebuild_name}" \
		|| e "creating ebuild for ${ebuild_name} failed"
	cp "${manifest_path}" "${package_name}/Manifest" \
		|| e "copying Manifest for ${ebuild_name} failed"

	ebuild "${package_name}/${ebuild_name}" manifest \
		|| e "updating Manifest failed"
}

if ! git status > /dev/null; then
	echo "this script removes and copies etc. stuff"
	echo "for safety, aborting, as you're not in a git repository"
	exit 2
fi

if [[ -n $(git status -s) ]]; then
	# this check is simple but should be good enough
	echo "your checkout is not \"clean\", aborting"
	exit 3
fi

if [[ $(basename "$(realpath .)") != "www-client" ]]; then
	echo "CWD should be www-client"
	exit 4
fi

echo "provide language list, from Firefox ebuild:"
read -a langs

[[ ${#langs[@]} -eq 0 ]] && e "No langs?"

echo "provide new version number:"
read new_version

def_manifest_path="/usr/portage/www-client/firefox/Manifest"
echo "provide location to Firefox's Manifest (${def_manifest_path} if empty):"
read manifest_path

manifest_path=${manifest_path:-${def_manifest_path}}
echo "Manifest path: ${manifest_path}"
[[ -e ${manifest_path} ]] || e "File does not exist."

[[ -z ${new_version} ]] && e "...should not be empty"
[[ ! ${new_version} =~ ^[0-9] ]] && e "...does not look correct"

package_name_prefix=firefox-l10n

# so that git doesn't remove the current directory if no other files are present
keepfile=keep-tmp-Fx-l10n
touch "${keepfile}" || e "creating ${keepfile} failed"
git rm -r "${package_name_prefix}"-* || e "git rm -r ${package_name_prefix}-* failed"

for lang in "${langs[@]}"; do
	# see mozlinguas_export in mozlinguas.eclass
	[[ ${lang} = en || ${lang//-/_} = en_US ]] && continue
	create_ebuild "${lang}" "${package_name_prefix}" "${new_version}"
done

rm "${keepfile}" || e "rm failed"

git add . || e "git add failed"
