#!/bin/bash

# Copyright © 2015 Julien Cerqueira (dicebox in #gentoo-hardened on freenode.net)

#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

##########
# Code organization
##########
# Notes
# Global variables
# Helper functions
#   Init helpers
#   Gawk helpers
#   Output helpers
#   Other helpers
# Core functions
#   Stack core
#   Run core
#   Update core
#   Clean core
# First level functions
#   usage
#   stack
#   run
#   update
#   clean
# Main

##########
# Notes
##########
# Number of occurences for some tests in the next two functions when called on a given profiles directory
#   create_rules_file:parent presence(602);one level(107);subbranch(76);todo(1)
#   restore_profile_file:parent presence(602); one level(107);subbranch(76);todo(1)
# We used that to choose the tests order
# Quick benchmarks show there is no sensible execution time difference by reordering tests

##########
# Global variables
##########
declare -r version="1.0"
declare -r copyright="Copyright © 2015 Julien Cerqueira (dicebox in #gentoo-hardened on freenode.net)"
declare -r scriptname="${0##*/}"
declare -r quickhack_tree="rules-quickhack"
declare -r pdesc="profiles.desc"
declare -r quickhack_profile="quickhack-profile"

testing=""
verbose=""

##########
# Helper functions
##########
init_options() {
    local shortopt="hVstvruc"
    local longopt="help,version,stack,test,verbose,run,update,clean"
    local options="$(getopt -o "$shortopt" --long "$longopt" -n 'example.bash' -- $@)"
    if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
    echo "$options"
}

init_start_path() {
    local start_path="$(return_start_path "$@")"

    if [[ -z "$start_path" ]]; then
	echo "Give the path to your profiles/ directory. Relative path accepted (give a dot if you are in that directory)"
	exit
    elif [[ ! -e "$start_path" ]]; then
	echo "Cannot find $start_path directory."
	exit
    fi

    local absolute_start_path="$(cd $start_path; pwd)"
    echo "$absolute_start_path"
}

init_quickhack_tree() {
    if [[ -e "$quickhack_tree" ]]; then
	echo "Profiles-quickhack has already applied changes on this directory. It can either --update or --clean these changes. Terminating..."
	exit 1
    elif [[ -z "$testing" ]];then
	mkdir "$quickhack_tree"
    else
	echo "mkdir $quickhack_tree"
    fi
}

init_run_list() {
    local parent_list="$(find "$1" -name "*parent" -not -path "*/$quickhack_tree/*")"
    echo "$parent_list"
}

init_clean_list() {
    local parent_list="$(find "$1" -name "*parent" -path "*/$quickhack_tree/*")"
    echo "$parent_list"
}

create_quickhack_description() {
    local description="$(gawk -v quickhack_tree="$quickhack_tree" '
        !/^($|#)/{
        n = split($0, field, " ", separator)
        field[2] = quickhack_tree"/"field[2]
        line = separator[0]
        for (i = 1; i <= n; ++i) line = line field[i] separator[i]
        print line }
        /^($|#)/{ print
        }' "$1/$pdesc")"

    echo "$description"
}

clean_quickhack_description() {
    local description="$(gawk -v quickhack_tree="$quickhack_tree" '
        !/^($|#)/{
        n = split($0, field, " ", separator)
        field[2] = substr(field[2], length(quickhack_tree)+2, length(field[2]))
        line = separator[0]
        for (i = 1; i <= n; ++i) line = line field[i] separator[i]
        print line }
        /^($|#)/{ print
        }' "$1/$pdesc")"

    echo "$description"
}

output_rules() {
    if [[ -z "$testing" ]];then
	echo "$1" >> "$rules_file"
    fi
    if [[ ! -z "$verbose" ]]; then
	echo "$1"
    fi
}

output_profiles_desc() {
    if [[ -z "$testing" ]];then
	echo "$2" > "$1/$pdesc"
    else
	echo "fill $1/$pdesc"
	if [[ ! -z "$verbose" ]];then
	    echo "$2"
	fi
    fi
}

return_start_path() {
    while [[ "$1" != "--" ]]; do
	shift;
    done
    shift
    local start_path="$1"
    echo "$start_path"
}

##########
# Core functions
##########
echo_rules_stack() {
    # Depth-first search algorithm
    local absolute_file_path="$(dirname "$1")"
    for dir in $(cat "$1"); do
	cd "$absolute_file_path/$dir"
	local absolute_leaf_path="$(pwd)"
	if [[ -e "parent" ]]; then
	    echo_rules_stack "$absolute_leaf_path/parent"
	else
	    echo "$absolute_leaf_path"
	fi
    done
    echo "$absolute_file_path"
}

create_rules_file() {
    local absolute_file_path="$(dirname "$2")"
    local absolute_leaf_path=""
    local copy_root_branch=""
    local root_branch=""
    local leaf_branch=""
    local root_first_dir=""
    local leaf_first_dir=""

    for dir in $(cat "$2"); do
	absolute_leaf_path="$(cd "$absolute_file_path/$dir"; pwd)"
	if [[ -e "$absolute_leaf_path/parent" ]]; then
	    if [[ ! -z "$testing" ]] && [[ ! -z "$verbose" ]]; then
		echo -n "Parent presence makes relative path the same: "
	    fi
	    output_rules "$dir" "$3"
	else
	    root_branch="${absolute_file_path#$1/}/"
	    leaf_branch="${absolute_leaf_path#$1/}"
	    root_first_dir="${root_branch%%/*}"
	    leaf_first_dir="${leaf_branch%%/*}"
	    if [[ "$leaf_first_dir" != "$root_first_dir" ]];then
		if [[ ! -z "$testing" ]] && [[ ! -z "$verbose" ]]; then
		    echo -n "Add one level because of $quickhack_tree/: "
		fi
		output_rules "../$dir" "$3"
	    elif [[ "$leaf_first_dir" == "$root_first_dir" ]]; then
		while [[ ! -z "$root_branch" ]]; do
		    root_branch="${root_branch#*/}"
		    leaf_branch="../$leaf_branch"
		done
		if [[ ! -z "$testing" ]] && [[ ! -z "$verbose" ]]; then
		    echo -n "New subbranch from the same root node: "
		fi
		output_rules "../$leaf_branch" "$3"
	    elif [[ "$dir" == "todo" ]]; then
		if [[ ! -z "$testing" ]] && [[ ! -z "$verbose" ]]; then
		    echo -n "Recognized pattern as Work in Progress: "
		fi
		output_rules "$dir" "$3"
	    else
		echo "Unknown node pattern. Terminating..."
		exit
	    fi
	fi
    done

    root_branch="${absolute_file_path#$1/}/"
    copy_root_branch="$root_branch"
    while [[ ! -z "$copy_root_branch" ]]; do
	copy_root_branch="${copy_root_branch#*/}"
	root_branch="../$root_branch"
    done
    if [[ ! -z "$testing" ]] && [[ ! -z "$verbose" ]]; then
	echo -n "Add current directory for other files present here: "
    fi
    output_rules "../$root_branch" "$3"
}

create_quickhack_rules() {
    for file in $2; do
	local file_path="${file%/parent}"
	local file_new_path="${file_path/$1/$1/$quickhack_tree}"

	if [[ -z "$testing" ]]; then
	    if [[ ! -e "$file_new_path" ]]; then
		mkdir --parents "$file_new_path"
	    fi
	else
	    echo "mkdir --parents $file_new_path"
	fi

	rules_file="$file_new_path/parent"
	if [[ -z "$testing" ]]; then
	    touch "$rules_file"
	else
	    echo "touch $rules_file"
	fi

	local absolute_file_path="$(cd $file_path; pwd)"
	create_rules_file "$1" "$absolute_file_path/parent" "$rules_file"
    done
}

create_quickhack_profiles_desc() {
    local quickhack_applied="$(grep $quickhack_tree $1/$pdesc)"
    if [[ -z "$quickhack_applied" ]]; then
	local description="$(create_quickhack_description "$1")"
	output_profiles_desc "$1" "$description"
    else
	echo "$pdesc has already been modified by $scriptname. Terminating..."
	exit
    fi
}

purge_profiles() {
    if [[ -z "$testing" ]];then
	find "$1" -name "*parent" -not -path "*/$quickhack_tree/*" -execdir rm '{}' \;
    else
	find "$1" -name "*parent" -not -path "*/$quickhack_tree/*" -exec echo "rm {}" \;
    fi
}

restore_profile_file() {
    local absolute_file_path="$(dirname "$2")"
    local copy_leaf_branch=""
    local root_branch=""
    local leaf_branch=""
    local root_first_dir=""
    local leaf_first_dir=""
    local leaf_last_same_dir=""

    for dir in $(cat "$2"); do
	absolute_leaf_path="$(cd "$absolute_file_path/$dir"; pwd)"
	root_branch="${absolute_file_path#$1/$quickhack_tree/}"
	leaf_branch="${absolute_leaf_path#$1/}"
	if [[ "$leaf_branch" != "$root_branch"  ]]; then
	    if [[ -e "$absolute_leaf_path/parent" ]]; then
		if [[ ! -z "$testing" ]] && [[ ! -z "$verbose" ]]; then
		    echo -n "Parent presence makes relative path the same: "
		fi
		output_rules "$dir" "$3"
	    else
		root_first_dir="${root_branch%%/*}"
		leaf_first_dir="${leaf_branch%%/*}"
		if [[ "$leaf_first_dir" != "$root_first_dir" ]]; then
		    dir="${dir#*/}"
		    if [[ ! -z "$testing" ]] && [[ ! -z "$verbose" ]]; then
			echo -n "Remove the added level because of $quickhack_tree/: "
		    fi
		    output_rules "$dir" "$3"
		elif [[ "$leaf_first_dir" == "$root_first_dir" ]]; then
		    copy_leaf_branch="$leaf_branch/"
		    copy_root_branch="$root_branch"
		    while [[ "$leaf_first_dir" == "$root_first_dir" ]]; do
			leaf_last_same_dir="$leaf_first_dir"
			copy_root_branch="${copy_root_branch#*/}"
			copy_leaf_branch="${copy_leaf_branch#*/}"
			root_first_dir="${copy_root_branch%%/*}"
			leaf_first_dir="${copy_leaf_branch%%/*}"
		    done
		    root_last_dir="${root_branch##*/}"
		    leaf_branch="$copy_leaf_branch"
		    while [[ "$root_last_dir" != "$leaf_last_same_dir" ]]; do
			root_branch="${root_branch%/*}"
			root_last_dir="${root_branch##*/}"
			leaf_branch="../$leaf_branch"
		    done
		    leaf_branch="${leaf_branch%/*}"
		    if [[ ! -z "$testing" ]] && [[ ! -z "$verbose" ]]; then
			echo -n "Rebuild relative path from the same root node: "
		    fi
		    output_rules "$leaf_branch" "$3"
		elif [[ "$dir" == "todo" ]]; then
		    if [[ ! -z "$testing" ]] && [[ ! -z "$verbose" ]]; then
			echo -n "Recognized pattern as Work in Progress: "
		    fi
		    output_rules "$dir" "$3"
		else
		    echo "Unknown node pattern. Terminating..."
		    exit
		fi
	    fi
	else
	    if [[ ! -z "$testing" ]] && [[ ! -z "$verbose" ]]; then
		echo -n "Current directory files are already sourced."
	    fi
	fi
    done

}

restore_profiles() {
    for file in $2; do
	cd "$1"
	local file_path="$(dirname "$file")"
	local file_new_path="$(echo "$file_path" | sed -e "s@$1/$quickhack_tree@$1@")"

	rules_file="$file_new_path/parent"
	if [[ ! -e "$rules_file" ]]; then
	    if [[ -z "$testing" ]];then
		touch "$rules_file"
	    else
		echo "touch $rules_file"
	    fi
	else
	    echo "$rules_file file exists. State of Portage profiles uncertain. Termintaing..."
	    exit
	fi

	local absolute_file_path="$(cd $file_path; pwd)"
	restore_profile_file "$1" "$absolute_file_path/parent" "$rules_file"
    done
}

restore_profiles_desc() {
    local quickhack_applied="$(grep $quickhack_tree $1/$pdesc)"
    if [[ ! -z "$quickhack_applied" ]]; then
	local description="$(clean_quickhack_description "$1")"
	output_profiles_desc "$1" "$description"
    else
	echo "$pdesc already looks clean. Terminating..."
	exit
    fi
}

backup_quickhack_profile() {

    if [[ -e "$1/parent" ]]; then
	echo "A backup of a custom profile already exists. Terminating..."
	exit
    fi
    if [[ -e "$1/$quickhack_tree/parent" ]]; then
	if [[ -z "$testing" ]];then
	    cp "$1/$quickhack_tree/parent" "$1/$quickhack_profile"
	else
	    echo "cp $1/$quickhack_tree/parent $1/$quickhack_profile"
	fi
    fi
}

purge_quickhack_tree() {
    if [[ -e "$1/$quickhack_tree/" ]]; then
	if [[ -z "$testing" ]];then
	    rm -Rf "$1/$quickhack_tree/"
	else
	    echo "rm -Rf $1/$quickhack_tree/"
	fi
    fi
}

##########
# First level functions
##########
usage() {
    cat <<EOF
Usage: $scriptname [OPTION]... [COMMAND] [PROFILES_DIR]
Rewrite and reorganize Portage parent files to permit to create a custom profile.
Attempt to address Gentoo bug #492312. See the Custom profile section for details.

On a Gentoo installation PROFILES_DIR should be /usr/portage/profiles.
$scriptname works with either a relative or absolute path to PROFILES_DIR.

Options:
  -t, --test  simulate and show files creation, deletion and modification
  -v, --verbose  add file content to --test output

Commands:
  -h, --help     display this help and exit
  -V, --version  show version and exit
  -s, --stack    print the stack of PROFILES_DIR
  -r, --run      create and fill rules tree, and purge original trees.
  -u, --update   update the rules-quickhack/ directory in PROFILES_DIR
               Comments: use it when your Portage tree has been updated
                        it backups your custom profile
  -c, --clean    clean any modification made by $scriptname in PROFILES_DIR
               Comment: it backups your custom profile

Examples:
$scriptname --version                                   Print version, copyright and license informations.
$scriptname --help                                      Print usage, tell about custom profile.
$scriptname --test --verbose --run .                    Show all changes that the run command would apply.
$scriptname --run .                                     Create rules tree, and purge original trees,
                                                                   relative path to PROFILES_DIR.
$scriptname --run /full/path/to/profiles_dir            Create rules tree, and purge original trees,
                                                                   absolute path to PROFILES_DIR.
$scriptname --update .                                  Update rules tree, and profiles.desc,
                                                                   relative path to PROFILES_DIR.
$scriptname --clean .                                   Restore original parent and profiles.desc files,
                                                                   purge rules tree, relative path to PROFILES_DIR.

Custom profile:
After you have used $scriptname on the PROFILES_DIR, drop a custom parent file in PROFILES_DIR/$quickhack_tree/.
A parent file contains simply a list of directories. Those directories contain what really make a Portage profile.
Here is the content of a parent file to create a hardened desktop profile:
  /usr/portage/profiles/base
  /usr/portage/profiles/default/linux
  /usr/portage/profiles/arch/base
  /usr/portage/profiles/features/multilib
  /usr/portage/profiles/features/multilib/lib32
  /usr/portage/profiles/arch/amd64
  /usr/portage/profiles/releases
  /usr/portage/profiles/releases/13.0
  /usr/portage/profiles/targets/desktop
  /usr/portage/profiles/hardened/linux
  /usr/portage/profiles/hardened/linux/amd64
Here is the content of a parent file to create a hardened desktop with systemd profile:
  /usr/portage/profiles/base
  /usr/portage/profiles/default/linux
  /usr/portage/profiles/arch/base
  /usr/portage/profiles/features/multilib
  /usr/portage/profiles/features/multilib/lib32
  /usr/portage/profiles/arch/amd64
  /usr/portage/profiles/releases
  /usr/portage/profiles/releases/13.0
  /usr/portage/profiles/targets/desktop
  /usr/portage/profiles/targets/systemd
  /usr/portage/profiles/hardened/linux
  /usr/portage/profiles/hardened/linux/amd64
You can use relative paths to that parent file instead:
  ../base
  ../default/linux
  ../arch/base
  ../features/multilib
  ../features/multilib/lib32
  ../arch/amd64
  ../releases
  ../releases/13.0
  ../targets/desktop
  ../targets/systemd
  ../hardened/linux
  ../hardened/linux/amd64
  ../hardened/linux/amd64/destkop
You could eventually reuse entires in the created rules tree.

This script considers that the only user file in the create rules tree is a parent file in the root directory of the created rules tree.

See the Portage documentations on Gentoo.org, as well as directly PORTAGE_DIR content,
to have a better comprehension of what is a Portage profile.
$scriptname version $version
$copyright
Released under GPLv3 or later
EOF
}

version() {
    echo "$scriptname $version"
    echo "$copyright"
    cat <<EOF
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
EOF
}

stack() {
    local start_path="$(return_start_path "$@")"
    local absolute_path=""
    if [[ -d "$start_path" ]] && [[ -e "$start_path/parent" ]]; then
	absolute_path="$(cd $start_path; pwd)"
	echo_rules_stack "$absolute_path/parent"
    elif [[ -d "$start_path" ]]; then
	echo "$start_path"
    elif [[ -e "$start_path" ]]; then
	absolute_path="$(cd $(dirname "$start_path"); pwd)"
	echo_rules_stack "$absolute_path/$(basename "$start_path")"
    else
	echo "stack path error"
	exit 1
    fi
}

run() {
    local absolute_start_path="$(init_start_path "$@")"
    local parent_list="$(init_run_list "$absolute_start_path")"

    init_quickhack_tree

    create_quickhack_profiles_desc "$absolute_start_path"
    create_quickhack_rules "$absolute_start_path" "$parent_list"

    purge_profiles "$absolute_start_path"
}

update() {
    local absolute_start_path="$(init_start_path "$@")"
    local parent_list="$(init_run_list "$absolute_start_path")"

    if [[ ! -e "$absolute_start_path/$quickhack_tree" ]]; then
	echo "Cannot find $quickhack directory. Terminating..."
	exit
    fi

    backup_quickhack_profile "$absolute_start_path"
    purge_quickhack_tree "$absolute_start_path"

    init_quickhack_tree

    create_quickhack_profiles_desc "$absolute_start_path"
    create_quickhack_rules "$absolute_start_path" "$parent_list"

    purge_profiles "$absolute_start_path"
}

clean() {
    local absolute_start_path="$(init_start_path "$@")"
    local parent_list="$(init_clean_list "$absolute_start_path")"

    restore_profiles_desc "$absolute_start_path"
    restore_profiles "$absolute_start_path" "$parent_list"
    backup_quickhack_profile "$absolute_start_path"

    purge_quickhack_tree "$absolute_start_path"
}

##########
# Main
##########
options="$(init_options "$@")"

eval set -- "$options"

while true ; do
    case "$1" in
        -h|--help) usage ; break ;;
        -V|--version) version; break ;;
        -s|--stack) stack "$@"; break ;;
        -t|--test) testing=1 ; shift ;;
        -v|--verbose) verbose=1 ; shift ;;
        --) echo "No command found! Use -h for help." ; break ;;
        *) case "$1" in
	    -r|--run) run "$@"; break ;;
	    -u|--update) update "$@"; break ;;
	    -c|--clean) clean "$@"; break ;;
            *) echo "Internal error! "; echo "$1"; exit 1 ;;
            esac ;;
    esac
done

exit $?
