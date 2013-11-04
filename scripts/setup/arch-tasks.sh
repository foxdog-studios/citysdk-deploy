# =============================================================================
# = Configuration                                                             =
# =============================================================================

repo=$(realpath "$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")/../..")

system_packages=(
    'git'
    'virtualbox'
)


# =============================================================================
# = Tasks                                                                     =
# =============================================================================

download_appliance() {
    local "res=${repo}/res"
    local "name=CitySDK.ova"
    local "path=${res}/${name}"
    local "md5=b4ae8f561e37979ccca4f9cbb0552a54"
    if ! md5sum --check <<< "${md5} ${path}"; then
        mkdir -p "${res}"
        scp "resource@foxdogstudios.com:${name}" "${path}"
    fi
}

install_system_packages() {
    sudo pacman --needed --noconfirm --refresh --sync "${system_packages[@]}"
}

