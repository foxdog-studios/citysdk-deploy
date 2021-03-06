#!/bin/bash

# Copyright 2013 Foxdog Studios
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

postgresql_version=9.3

postgis_version=2.1

osm2pgsql_tag=v0.82.0

db_name=citysdk

citysdk_commit=fad84044e4de679452675d9f7c3f9d9e51b79480

osm_uri=http://download.geofabrik.de/europe-latest.osm.pbf


# = Packages ==================================================================

aptitude=(
    # PostgreSQL
        "postgresql-${postgresql_version}"
        "postgresql-contrib-${postgresql_version}"

    # PostGIS
        "postgresql-${postgresql_version}-postgis-${postgis_version}"

    # osm2pgsql
        'autoconf'
        'g++'
        'git'
        'libbz2-dev'
        'libgeos++-dev'
        'libpq-dev'
        'libprotobuf-c0-dev'
        'libtool'
        'libxml2-dev'
        "postgresql-server-dev-${postgresql_version}"
        'proj'
        'protobuf-c-compiler'
        'zlib1g-dev'

    # Ruby
        'libcurl4-openssl-dev'
        # charlock_holmes
            'libicu-dev'

    # Memcached
        'memcached'
)

gems=(
    'capistrano     -v 2.15.4'
    'capistrano-ext -v 1.2.1 '
    'passenger      -v 4.0.23'
)


# = Paths =====================================================================

build_path=${HOME}/build

osm2pgsql_name=osm2pgsql

osm2pgsql_path=${build_path}/${osm2pgsql_name}

citysdk_name=citysdk

citysdk_path=${build_path}/${citysdk_name}

citysdk_gem_path=${citysdk_path}/gem

osm_name=europe-latest.osm.pbf

osm_path=${build_path}/${osm_name}


# =============================================================================
# = Helpers                                                                   =
# =============================================================================

apt-get() {
    sudo apt-get --assume-yes "${@}"
}


codename() {
    lsb_release --codename --short
}


ensure_build() {
    mkdir -p "${build_path}"
}


pg() {
    sudo -u postgres "${@}"
}


psql() {
    pg psql "${db_name}" "${@}"
}


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

# = Aptitude (1) ==============================================================

aptitude_curl() {
    # cURL is required by postgresql_ppa and RVM
    apt-get install curl
}


# = PostgreSQL ================================================================

postgresql_ppa() {
    sudo tee /etc/apt/sources.list.d/pgdg.list <<-EOF
		deb http://apt.postgresql.org/pub/repos/apt/ $(codename)-pgdg main
	EOF
    local 'url=http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc'
    curl "${url}" | sudo apt-key add -
}


# = Aptitude (2) ==============================================================

aptitude_update() {
    apt-get update
}


aptitude_install() {
    apt-get install "${aptitude[@]}"
}


aptitude_upgrade() {
    apt-get dist-upgrade
    apt-get autoremove
}


# = osm2pgsql =================================================================

osm2pgsql_clone() {
    ensure_build
    if [[ ! -d "${osm2pgsql_path}" ]]; then
        local "url=https://github.com/openstreetmap/${osm2pgsql_name}.git"
        git clone "${url}" "${osm2pgsql_path}"
    fi
}


osm2pgsql_checkout() {(
    cd -- "${osm2pgsql_path}"
    git checkout "${osm2pgsql_tag}"
)}


osm2pgsql_configure() {(
    cd -- "${osm2pgsql_path}"
    ./autogen.sh
    ./configure
    patch Makefile <<-"EOF"
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


# = Ruby ======================================================================

ruby_gemrc() {
    sudo tee /etc/gemrc <<< 'gem: --no-rdoc --no-ri'
}


ruby_rvm() {
    sudo -s <<-EOF
		set -o errexit
		set -o nounset
		curl -L https://get.rvm.io | bash -s stable --rails
	EOF
}


ruby_gems() {
    for gem in "${gems[@]}"; do
        sudo -s <<-EOF
			set -o errexit
			source /usr/local/rvm/scripts/rvm
			gem install --verbose ${gem}
		EOF
    done
}


ruby_passenger() {
    sudo -s <<-"EOF"
		set -o errexit
		source /usr/local/rvm/scripts/rvm
		cd -- "$(passenger-config --root)"
		./bin/passenger-install-nginx-module \
		        --auto                       \
		        --auto-download              \
		        --prefix=/usr/local/nginx
	EOF
}


# = CitySDK ===================================================================

citysdk_clone() {
    ensure_build
    local "url=https://github.com/waagsociety/${citysdk_name}.git"
    if [[ ! -d "${citysdk_path}" ]]; then
        git clone "${url}" "${citysdk_path}"
    fi
}


citysdk_checkout() {(
    cd -- "${citysdk_path}"
    git checkout "${citysdk_commit}"
)}


citysdk_deploy() {(
    set +o nounset
    source /usr/local/rvm/scripts/rvm
    set -o nounset
    cd -- "${citysdk_path}/server"
    cap production deploy
)}


citysdk_gem_build() {(
    set +o nounset
    source /usr/local/rvm/scripts/rvm
    set -o nounset
    cd -- "${citysdk_gem_path}"
    gem build citysdk.gemspec
)}


citysdk_gem_install() {
    sudo -s <<-EOF
		set -o errexit
		source /usr/local/rvm/scripts/rvm
		cd -- "${citysdk_gem_path}"
		gem install --verbose citysdk-*.gem
	EOF
}


# = Database ==================================================================

db_create() {
    # XXX: Always succeeding may mask problems. Instead query for the
    #      database and only create it if it does not exist.
    pg createdb "${db_name}" || true
}


db_extensions() {
    psql <<-"EOF"
		CREATE EXTENSION IF NOT EXISTS hstore;
		CREATE EXTENSION IF NOT EXISTS pg_trgm;
		CREATE EXTENSION IF NOT EXISTS postgis;
	EOF
}


# = OpenStreetMap =============================================================

osm_download() {
    ensure_build
    if [[ -f "${osm_path}" ]]; then
        echo 'OSM data appears to have been downloaded already'
    else
        curl -L "${osm_uri}" > "${osm_path}"
    fi
}


osm_import() {
    pg osm2pgsql --cache 1000 --database "${db_name}" "${osm_path}"
}


# =============================================================================
# = Command line interface                                                    =
# =============================================================================

all_tasks=(
    aptitude_curl

    postgresql_ppa

    aptitude_update
    aptitude_install
    aptitude_upgrade

    osm2pgsql_clone
    osm2pgsql_checkout
    osm2pgsql_configure
    osm2pgsql_build
    osm2pgsql_install

    ruby_gemrc
    ruby_rvm
    ruby_gems
    ruby_passenger

    citysdk_clone
    citysdk_checkout
    citysdk_deploy
    citysdk_gem_build
    citysdk_gem_install

    db_create
    db_extensions

    osm_download
    osm_import
)

usage() {
    cat <<-"EOF"
		Set up CitySDK on this machine

		Usage:

		    setup.sh [-s TASK_ID | [TASKS...]]

		Tasks:
		     1) aptitude_curl
		     2) postgresql_ppa
		     3) aptitude_update
		     4) aptitude_install
		     5) aptitude_upgrade
		     6) osm2pgsql_clone
		     7) osm2pgsql_checkout
		     8) osm2pgsql_configure
		     9) osm2pgsql_build
		    10) osm2pgsql_install
		    11) ruby_gemrc
		    12) ruby_rvm
		    13) ruby_gems
		    14) ruby_passenger
		    15) citysdk_clone
		    16) citysdk_checkout
		    17) citysdk_deploy
		    18) citysdk_gem_build
		    19) citysdk_gem_install
		    20) db_create
		    21) db_extensions
		    22) osm_download
		    23) osm_import
	EOF
    exit 1
}

start_id=0

while getopts :s: opt; do
    case "${opt}" in
        s) start_id=${OPTARG} ;;
        \?|*) usage ;;
    esac
done

shift $(( OPTIND - 1 ))

if [[ "${start_id}" != 0 ]]; then
    if [[ "${#}" != 0 ]]; then
        usage
    fi
    start_id=$[ start_id - 1 ]
    tasks=( "${all_tasks[@]:${start_id}}" )
else
    tasks=( "${@:-${all_tasks[@]}}" )
fi

for task in "${tasks[@]}"; do
    echo -e "\n\e[5;34mTask: ${task}\e[0m\n"
    ${task}
done

