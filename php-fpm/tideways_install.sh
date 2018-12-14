#!/usr/bin/env bash
# Tideways with XHgui
called=$_ && [[ ${called} != $0 ]] && echo "${BASH_SOURCE[@]} is being sourced" || echo "${0} is being run"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
TIDEWAYS=`dirname ${SCRIPT_PATH}` && cd ${TIDEWAYS} && cd ../.. && export QM_API="$PWD" && echo "HOSTNAME is ${HOSTNAME} and QM_API is $QM_API"
install_tideways() {
    # Tideways is only for php =>7.0
    echo "Installing/update Tideways to PHP 7.0, 7.1, 7.2"
    git clone "https://github.com/tideways/php-xhprof-extension" "/var/local/tideways-php7.2"
    cp -r /var/local/tideways-php7.2 /var/local/tideways-php7.0
    cp -r /var/local/tideways-php7.2 /var/local/tideways-php7.1
    for version in 7.0 7.1 7.2
        do
        cd "/var/local/tideways-php${version}"
        update-alternatives --set php /usr/bin/php${version}
        update-alternatives --set php-config /usr/bin/php-config${version}
        update-alternatives --set phpize /usr/bin/phpize${version}
        phpize${version}
        ./configure --enable-tideways-xhprof --with-php-config=php-config${version}
        make
        make install
    done
}
restart_php() {
    if [[ -d "/etc/php/7.0/" ]]; then
        service php7.0-fpm restart
    fi
    if [[ -d "/etc/php/7.1/" ]]; then
        service php7.1-fpm restart
    fi
    if [[ -d "/etc/php/7.2/" ]]; then
        service php7.2-fpm restart
    fi
}
install_mongodb() {
    set -x
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
    echo "deb http://repo.mongodb.org/apt/ubuntu trusty/mongodb-org/3.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.4.list
    sudo apt update >/dev/null
    apt-get -y install mongodb-org re2c
    sudo pecl install mongodb
    ln -s /usr/lib/php/20151012/mongodb.so /usr/lib/php/20170718/mongodb.so
    ln -s /usr/lib/php/20160303/mongodb.so /usr/lib/php/20170718/mongodb.so
    phpenmod mongodb
    # auto-remove records older than 2592000 seconds (30 days)
    mongo xhprof --eval 'db.collection.ensureIndex( { "meta.request_ts" : 1 }, { expireAfterSeconds : 2592000 } )'
    # indexes
    mongo xhprof --eval  "db.collection.ensureIndex( { 'meta.SERVER.REQUEST_TIME' : -1 } )"
    mongo xhprof --eval  "db.collection.ensureIndex( { 'profile.main().wt' : -1 } )"
    mongo xhprof --eval  "db.collection.ensureIndex( { 'profile.main().mu' : -1 } )"
    mongo xhprof --eval  "db.collection.ensureIndex( { 'profile.main().cpu' : -1 } )"
    mongo xhprof --eval  "db.collection.ensureIndex( { 'meta.url' : 1 } )"
    update-rc.d mongodb defaults
    update-rc.d mongodb enable
}
echo "Installing Tideways & XHgui"
if [[ ! -d "$QM_API/vendor/perftools/xhgui" ]]; then
    if [[ -d "/etc/php/7.0/" ]]; then
        echo "File copied for php 7.0"
        cp "${TIDEWAYS}/tideways.ini" "/etc/php/7.0/mods-available/tideways_xhprof.ini"
        cp "${TIDEWAYS}/mongodb.ini" "/etc/php/7.0/mods-available/mongodb.ini"
        cp "${TIDEWAYS}/xhgui-php.ini" "/etc/php/7.0/mods-available/xhgui.ini"
    fi
    if [[ -d "/etc/php/7.1/" ]]; then
        echo "File copied for php 7.1"
        cp "${TIDEWAYS}/tideways.ini" "/etc/php/7.1/mods-available/tideways_xhprof.ini"
        cp "${TIDEWAYS}/mongodb.ini" "/etc/php/7.1/mods-available/mongodb.ini"
        cp "${TIDEWAYS}/xhgui-php.ini" "/etc/php/7.1/mods-available/xhgui.ini"
    fi
    if [[ -d "/etc/php/7.2/" ]]; then
        echo "File copied for php 7.2"
        cp "${TIDEWAYS}/tideways.ini" "/etc/php/7.2/mods-available/tideways_xhprof.ini"
        cp "${TIDEWAYS}/xhgui-php.ini" "/etc/php/7.2/mods-available/xhgui.ini"
        # For the default php version
        cp "${TIDEWAYS}/mongodb.ini" "/etc/php/7.2/mods-available/mongodb.ini"
    fi
    #install_mongodb  # Not necessary because we use remote MongoDB
    install_tideways
    phpenmod tideways_xhprof
    echo -e "\nDownloading xhgui, see https://github.com/perftools/xhgui"
    #git clone "https://github.com/mikepsinn/xhgui" "/vagrant/vendor/perftools/xhgui"
    cd ${QM_API} && composer install
    cd ${QM_API}/vendor/perftools/xhgui
    php install.php
    cp "${TIDEWAYS}/config.php" "${QM_API}/vendor/perftools/xhgui/config/config.php"
    cp "${TIDEWAYS}/tideways-header.php" "${QM_API}/vendor/perftools/xhgui/config/tideways-header.php"
    cp "${TIDEWAYS}/nginx.conf" "/etc/nginx/custom-sites/xhgui.conf"
    restart_php
    service mongodb restart
    if [[ -d "/etc/php/7.0/" ]]; then
        php7.0 --ri tideways_xhprof
    fi
    if [[ -d "/etc/php/7.0/" ]]; then
        php7.1 --ri tideways_xhprof
    fi
    php --ri tideways_xhprof
else
    echo -e "\nUpdating xhgui..."
    cd ${QM_API}/vendor/perftools/xhgui
    git pull --rebase origin master
    rm -rf /var/local/tideways-php7.0
    rm -rf /var/local/tideways-php7.1
    rm -rf /var/local/tideways-php7.2
    install_tideways
    make
    make install
    restart_php
fi
echo "* Added xhgui.vvv.test to /etc/hosts"
echo "127.0.0.1 xhgui.vvv.test # vvv-provision" >> "/etc/hosts"
