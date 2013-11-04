#!/bin/bash

# Copyright 2013 FOXDOG STUDIOS LTD
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset


# =============================================================================
# = Configuration                                                             =
# =============================================================================

# = Versions ==================================================================

postgresql_version=9.3

postgis_version=2.1

osm2pgsql_tag=v0.82.0


# = Packages ==================================================================

packages=(
    # PostgreSQL
    "postgresql-${postgresql_version}"
    "postgresql-contrib-${postgresql_version}"

    # PostGIS
    "postgresql-${postgresql_version}-postgis-${postgis_version}"

    # osm2pgsql
    "postgresql-server-dev-${postgresql_version}"
    'autoconf'
    'git'
    'libbz2-dev'
    'libgeos++-dev'
    'libpq-dev'
    'libprotobuf-c0-dev'
    'libtool'
    'libxml2-dev'
    'proj'
    'protobuf-c-compiler'
    'zlib1g-dev'
)


# = Paths =====================================================================

build_path=${HOME}/build

osm2pgsql_name=osm2pgsql

osm2pgsql_path=${build_path}/${osm2pgsql_name}


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

aptget() {
    sudo apt-get --assume-yes "${@}"
}


codename() {
    lsb_release --codename --short
}


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

setup() {
    postgresql_ppa

    packages_update
    packages_install
    packages_upgrade

    osm2pgsql_checkout
    osm2pgsql_configure
    osm2pgsql_build
    osm2pgsql_install
}


# = PostgreSQL ================================================================

postgresql_ppa() {
    sudo tee /etc/apt/sources.list.d/pgdg.list <<-EOF
		deb http://apt.postgresql.org/pub/repos/apt/ $(codename)-pgdg main
	EOF
    local "url=http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc"
    wget --output-document - --quiet "${url}" | sudo apt-key add -
}


# = Packages ==================================================================

packages_update() {
    aptget update
}


packages_install() {
    aptget install "${packages[@]}"
}


packages_upgrade() {
    aptget dist-upgrade
    aptget autoremove
}


# = osm2pgsql =================================================================

osm2pgsql_checkout() {(
    mkdir -p "${build_path}"
    local url="https://github.com/openstreetmap/${osm2pgsql_name}.git"
    git clone "${url}" "${osm2pgsql_path}"
    cd -- "${osm2pgsql_path}"
    git checkout "${osm2pgsql_tag}"

)}


osm2pgsql_configure() {(
    cd -- "${osm2pgsql_path}"
    ./autogen.sh
    ./configure
    patch Makefile <<-EOF
		229c229
		< CFLAGS = -g -O2
		---
		> CFLAGS = -O2 -march=native -fomit-frame-pointer
		235c235
		< CXXFLAGS = -g -O2
		---
		> CXXFLAGS = -O2 -march=native -fomit-frame-pointer
	EOF
)}


osm2pgsql_build() {(
    cd -- "${osm2pgsql_path}"
    make "--jobs=$(nproc)"
)}


osm2pgsql_install() {(
    cd -- "${osm2pgsql_path}"
    sudo make install
)}


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

usage() {
    cat <<-EOF
		Set up CitySDK on this machine

		Usage:

		    setup.sh [TASK...]

		    TASK    A tasks to perform (see "Tasks"). If none are given, the
		            "setup" task is performed.

		Tasks:
		    setup
		    postgresql_ppa
		    packages_update
		    packages_install
		    packages_upgrade
		    osm2pgsql_build
		    osm2pgsql_configure
		    osm2pgsql_checkout
		    osm2pgsql_install
	EOF
    exit 1
}


while getopts : opt; do
    case "${opt}" in
        \?|*) usage ;;
    esac
done


shift $(( OPTIND - 1 ))


for task in "${@:-setup}"; do
    ${task}
done

