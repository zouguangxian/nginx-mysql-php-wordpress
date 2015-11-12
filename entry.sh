#!/bin/bash

# refer: http://stackoverflow.com/questions/4023830/bash-how-compare-two-strings-in-version-format
vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

# compver ver1 '=|==|>|<|>=|<=' ver2
compver() { 
    local op
    vercomp $1 $3
    case $? in
        0) op='=';;
        1) op='>';;
        2) op='<';;
    esac
    [[ $2 == *$op* ]] && return 0 || return 1
}

MYSQL_MAJOR="$(mysqld --version --help 2>/dev/null | grep '^mysqld' | sed 's,mysqld[[:space:]]*Ver[[:space:]]*\([0-9]*\.[0-9]*\.[0-9]*\).*,\1,g')"
DATA_DIR="$(mysqld --verbose --help 2>/dev/null | awk '$1 == "datadir" { print $2; exit }')"
WORDPRESS_DB="wordpress"

if [ ! -d "$DATA_DIR/mysql" ]; then
	# refer: https://dev.mysql.com/doc/refman/5.7/en/mysql-install-db.html
	echo 'Initializing database'
	vercomp ${MYSQL_MAJOR} "5.7.6"
	if [ $? = ">" ]; then
		mysqld --initialize-insecure=on
	else
		mysql_install_db
	fi
	echo 'Database initialized'

	mysqld --skip-innodb-use-native-aio --skip-networking & 

	MYSQL_PASSWORD=`pwgen -c -n -1 12`
	WORDPRESS_PASSWORD=`pwgen -c -n -1 12`

	mysqladmin=( mysqladmin )
	mysql=( mysql --protocol=socket -uroot )

	for i in {30..0}; do
		if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
			break
		fi
		echo 'MySQL init process in progress...'
		sleep 1
	done
	if [ "$i" = 0 ]; then
		echo >&2 'MySQL init process failed.'
		exit 1
	fi

	# set root password
	cmd=( "${mysqladmin[@]}" -u root password "${MYSQL_PASSWORD}" )	
	"${cmd[@]}" 

 	cmd=( "${mysql[@]}" -p"${MYSQL_PASSWORD}" )
 	"${cmd[@]}" <<-ENDL
		CREATE DATABASE ${WORDPRESS_DB}; 
		GRANT ALL PRIVILEGES ON ${WORDPRESS_DB}.* TO 'wordpress'@'%' IDENTIFIED BY '${WORDPRESS_PASSWORD}';
		FLUSH PRIVILEGES ;
	ENDL

	echo "root password: ${MYSQL_PASSWORD}"
	echo "wordpress password: ${MYSQL_PASSWORD}"
	echo "root: ${MYSQL_PASSWORD}" > ${DATA_DIR}/passwords.txt
	echo "wordpress: ${WORDPRESS_PASSWORD}" >> ${DATA_DIR}/passwords.txt
fi


if [ ! "$(ls -A /var/www/html)" ]; then
	if [ -d /srv/install-files ]; then
		cp /srv/install-files/wordpress-*.tar.gz /tmp
		cp /srv/install-files/nginx-helper.*.zip /tmp
	else
		cd /tmp && { curl -O https://wordpress.org/latest.tar.gz; mv latest.tar.gz wordpress-latest.tar.gz; cd -; }
		cd /tmp && { curl -O `curl -i -s https://wordpress.org/plugins/nginx-helper/ | egrep -o "https://downloads.wordpress.org/plugin/[^']+"`; cd-;}
	fi
	tar -zxvf /tmp/wordpress-*.tar.gz --strip-components 1 -C /var/www/html
	unzip -o /tmp/nginx-helper.*.zip -d /var/www/html/wp-content/plugins
else
	if [ ! -f /var/www/html/wp-content ]; then
		echo "WARNING: /var/www/html already exists."
		exit 1
	fi
fi

if [ ! -f /var/www/html/wp-config.php ]; then
	if [ ! -f ${DATA_DIR}/passwords.txt ]; then
		echo "WARNING: ${DATA_DIR}/passwords.txt does not exist."
		exit 1
	fi
	WORDPRESS_PASSWORD=`cat ${DATA_DIR}/passwords.txt | awk '$1 == "wordpress:" { print $2;exit }'`
	sed -e "s/database_name_here/$WORDPRESS_DB/
	s/username_here/$WORDPRESS_DB/
	s/password_here/$WORDPRESS_PASSWORD/
	/'AUTH_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
	/'SECURE_AUTH_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
	/'LOGGED_IN_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
	/'NONCE_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
	/'AUTH_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
	/'SECURE_AUTH_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
	/'LOGGED_IN_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
	/'NONCE_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/" /var/www/html/wp-config-sample.php > /var/www/html/wp-config.php
	chown www-data:www-data /var/www/html/wp-config.php
fi


killall mysqld
/usr/bin/supervisord -n




