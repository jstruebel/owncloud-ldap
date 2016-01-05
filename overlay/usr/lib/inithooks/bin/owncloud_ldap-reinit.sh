#!/bin/bash -e

fatal() {
    echo "fatal: $@" 1>&2
    exit 1
}

usage() {
cat<<EOF
Syntax: $(basename $0) server base binddn password
Re-initialize owncloud ldap

Arguments:
    server          # LDAP server
    base            # LDAP directory base
    binddn          # LDAP user
    password        # LDAP user password

EOF
    exit 1
}

if [[ "$#" != "4" ]]; then
    usage
fi

LDAP_SERVER=$1
LDAP_BASEDN=$2
LDAP_BINDDN=$3
LDAP_PASS=$(printf "$4" | base64)

# Customize app settings
MYSQL="/usr/bin/mysql --defaults-file=/etc/mysql/debian.cnf --batch --execute"
MYSQL_RUNNING=$(service mysql status > /dev/null; echo $?)
DB_NAME=owncloud
APPCFG=$DB_NAME.appconfig

# Start MySQL server if not running
if [ "$MYSQL_RUNNING" != "0" ]; then
    service mysql start
fi

# Set ldap options
for CFG in \
  "configvalue=\"$LDAP_PASS\" where appid=\"user_ldap\" and configkey=\"ldap_agent_password\"" \
  "configvalue=\"$LDAP_BASEDN\" where appid=\"user_ldap\" and configkey=\"ldap_base\"" \
  "configvalue=\"ou=Groups,$LDAP_BASEDN\" where appid=\"user_ldap\" and configkey=\"ldap_base_groups\"" \
  "configvalue=\"ou=Users,$LDAP_BASEDN\" where appid=\"user_ldap\" and configkey=\"ldap_base_users\"" \
  "configvalue=\"$LDAP_BINDDN\" where appid=\"user_ldap\" and configkey=\"ldap_dn\"" \
  "configvalue=\"ldaps://$LDAP_SERVER\" where appid=\"user_ldap\" and configkey=\"ldap_host\""
  "configvalue=\"636\" where appid=\"user_ldap\" and configkey=\"ldap_port\""
do
  $MYSQL "update $APPCFG set $CFG;"
done

if [ "$MYSQL_RUNNING" != "0" ]; then
    service mysql stop
fi

cat >> /etc/inithooks.conf <<EOF
export LDAP_BASEDN=$LDAP_BASEDN
export LDAP_SERVER=$LDAP_SERVER
EOF

