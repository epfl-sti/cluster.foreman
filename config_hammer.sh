#!/bin/bash
#
# Configure Foreman for an EPFL STI cluster master
#
# DONE:
#  * LDAP connectivity
#  * User group
# TODO (or do it via Puppet):
#  * Roles (openstack-sti@ as admin group)
#  * Basic networking (subnet, domain)
#  * Smart proxy setup
#  * Provisioning setup
#  * More tweaks needed to get CentOS to install when selected
#    (binding between provisioning templates, OS, host groups and
#    environments)
#
# Hammer works out-of-the-box as a CLI bridge to the
# API. (See
# /usr/share/foreman-installer/modules/foreman/manifests/cli.pp)
#
# The reason is that foreman-installer somehow copies the admin
# password from /etc/foreman/foreman-installer-answers.yaml into
# /root/.hammer/cli.modules.d/foreman.yml
#
# But it's so much more fun to re-do everything ourselves :)
#
# API usage: http://theforeman.org/api/apidoc/v2.html


# Todo
#   - Set ROLES

# Debug ?
set -e -x

# The configuration file
STI_CONFIG_FILE='./sticonfig.cfg'
# Include configuration file
if [ -f $STI_CONFIG_FILE ]; then
    # source the config file
    . $STI_CONFIG_FILE
else
    echo "No config file found, please run ./init.sh to create $STI_CONFIG_FILE"
    exit 0
fi

# Generic function to search for ID of specified source
# Usage : getSourceId subcommands keywords
# Usage : getSourceId subcommands keywords
#  e.g. : getSourceId auth-source "EPFL LDAP"
#  Tips : hammer --help to get availables subcommands
getSourceId() {
    sourceId=0;
    if test -z "$1" || test -z "$2" || test "$#" -ne 2; then
        echo "Error: getTemplateId() needs\n 1) the name of the source, e.g. auth \n 2)the source desc name as input.\nE.g. getSourceId auth-source \"EPFL LDAP\""
        exit 0
    else
        echo "searching for $1->$2's id";
        sourceId=$(hammer $1 --search "$2" | grep "$2" | grep -wo "^[0-9]*");
        if test $sourceId -ne 0; then
            #returned value
            echo "$sourceId"
        else
            echo "Error: no $1's ID found for $1->$2"
            exit 0
        fi
    fi
}


#
#    AUTH SOURCES - http://theforeman.org/api/apidoc/v2/auth_source_ldaps.html
#
# Get auth_source_info
echo "-- Auth Source Info ------------------------------------------------------------"
hammer auth-source ldap list
#curl -i -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" -u ${EPFLSTI_CLUSTER_USER}:${EPFLSTI_CLUSTER_PASS} http://${EPFLSTI_CLUSTER_FOREMAN_IP}/api/auth_source_ldaps

# @TODO: search for EPFLSTI_CLUSTER_AUTH_SRC_NAME in the result of hammer auth-source ldap list
# No --search option for auth-source in hammer (sigh), old freestyle mode
# Note: other way to do it is to check it with
#       $ hammer auth-source ldap info --name "$EPFLSTI_CLUSTER_AUTH_SRC_NAME"
# debug :
echo "Searching for $EPFLSTI_CLUSTER_AUTH_SRC_NAME ID"
EPFLSTI_CLUSTER_AUTH_SRC_ID=$(hammer auth-source ldap list --per-page 1000 | grep "$EPFLSTI_CLUSTER_AUTH_SRC_NAME" | grep -wo "^[0-9]*" || true)
# debug :
echo "EPFLSTI_CLUSTER_AUTH_SRC_ID = $EPFLSTI_CLUSTER_AUTH_SRC_ID"
if [ -z "${EPFLSTI_CLUSTER_AUTH_SRC_ID}" ]; then
  # debug :
  echo "$EPFLSTI_CLUSTER_AUTH_SRC_ID Not found, creating it"
  # get auth src id, now update it
  # List the info
  hammer auth-source ldap info --id $EPFLSTI_CLUSTER_AUTH_SRC_ID
  # Update info
  # hammer auth-source ldap update --id $EPFLSTI_CLUSTER_AUTH_SRC_ID
else
  # debug :
  echo "$EPFLSTI_CLUSTER_AUTH_SRC_ID found, updating it"
  # this auth src id doesn't exists, create it
  hammer auth-source ldap create \
    --name ${EPFLSTI_CLUSTER_AUTH_SRC_NAME} \
    --host ${EPFLSTI_CLUSTER_LDAP_HOST} \
    #--type ${EPFLSTI_CLUSTER_LDAP_TYPE} \ # (@ISSUE? NOT IN THE Vhammer auth-source ldap update --help)
    --tls ${EPFLSTI_CLUSTER_LDAP_TLS} \
    --port ${EPFLSTI_CLUSTER_LDAP_PORT} \
    --account ${EPFLSTI_CLUSTER_LDAP_USER} \
    --account-password ${EPFLSTI_CLUSTER_LDAP_PASS} \
    --base-dn ${EPFLSTI_CLUSTER_LDAP_BASE} \
    #--groups-base ${EPFLSTI_CLUSTER_LDAP_BASE} \ #  (@ISSUE? NOT IN THE Vhammer auth-source ldap update --help)
    #--ldap-filter ${EPFLSTI_CLUSTER_LDAP_FILTER} \ #  (@ISSUE? NOT IN THE Vhammer auth-source ldap update --help)
    --onthefly-register ${EPFLSTI_CLUSTER_LDAP_REG} \
    --attr-login ${EPFLSTI_CLUSTER_LDAP_ATT_LOGIN} \
    --attr-firstname ${EPFLSTI_CLUSTER_LDAP_ATT_FIRST} \
    --attr-lastname ${EPFLSTI_CLUSTER_LDAP_ATT_LAST} \
    --attr-mail ${EPFLSTI_CLUSTER_LDAP_ATT_MAIL} \
    --attr-photo ${EPFLSTI_CLUSTER_LDAP_ATT_PHOTO}

  : '
  Usage:
      hammer auth-source ldap create [OPTIONS]

  Options:
   --account ACCOUNT
   --account-password ACCOUNT_PASSWORD   required if onthefly_register is true
   --attr-firstname ATTR_FIRSTNAME       required if onthefly_register is true
   --attr-lastname ATTR_LASTNAME         required if onthefly_register is true
   --attr-login ATTR_LOGIN               required if onthefly_register is true
   --attr-mail ATTR_MAIL                 required if onthefly_register is true
   --attr-photo ATTR_PHOTO
   --base-dn BASE_DN
   --host HOST
   --name NAME
   --onthefly-register ONTHEFLY_REGISTER
   --port PORT                           defaults to 389
   --tls TLS
   -h, --help                            print help
  '
  EPFLSTI_CLUSTER_AUTH_SRC_ID=$(hammer auth-source ldap list --per-page 1000 | grep "$EPFLSTI_CLUSTER_AUTH_SRC_NAME" | grep -wo "^[0-9]*")
  if [ -z "${EPFLSTI_CLUSTER_AUTH_SRC_ID}" ]; then
    echo "$EPFLSTI_CLUSTER_AUTH_SRC_NAME created with id=$EPFLSTI_CLUSTER_AUTH_SRC_ID"
  else
    echo "$EPFLSTI_CLUSTER_AUTH_SRC_NAME creation failure"
    exit 0
  fi
fi

# @TODO: if the EPFLSTI_CLUSTER_AUTH_SRC_NAME (LDAP authentification source)
#         exists -> update it else create it

if [ -z $EPFLSTI_CLUSTER_AUTH_SRC_ID ]; then
#
#    USER GROUP - http://theforeman.org/api/apidoc/v2/usergroups.html
#
# @TODO: 1) search for it
#        2) update or create it


#
#    EXTERNAL USER GROUP - http://theforeman.org/api/apidoc/v2/external_usergroups.html
#
# @TODO: 1) search for it
#        2) update or create it


#
#    ROLES - http://theforeman.org/api/apidoc/v2/roles.html
#
# @TODO: 1) search for them
#        2) update or create them
#       => Create/update 2 roles:
#       STI-Smart-Admin
#       STI-Begginer-Admin




exit 0
#
#  BELOW THE CURL WAY TO DO IT, TO BE REMOVED
#


# Create LDAP authentification source
#	http://theforeman.org/api/apidoc/v2/auth_source_ldaps.html
echo "-- Creating the LDAP auth source -----------------------------------------------"
C_LDAP_AUTH=$(curl -s -u ${EPFLSTI_CLUSTER_USER}:${EPFLSTI_CLUSTER_PASS} -X POST -d "{\"auth_source_ldap\":{\"name\": \
  \"${EPFLSTI_CLUSTER_AUTH_SRC_NAME}\",\"host\": \"${EPFLSTI_CLUSTER_LDAP_HOST}\",\"tls\":${EPFLSTI_CLUSTER_LDAP_TLS}, \
  \"port\":${EPFLSTI_CLUSTER_LDAP_PORT},\"server_type\":\"${EPFLSTI_CLUSTER_LDAP_TYPE}\",\"account\":${EPFLSTI_CLUSTER_LDAP_USER}, \
  \"account_password\":${EPFLSTI_CLUSTER_LDAP_PASS},\"base_dn\":\"${EPFLSTI_CLUSTER_LDAP_BASE}\",\"groups_base\":\"${EPFLSTI_CLUSTER_LDAP_BASE}\", \
  \"ldap_filter\":${EPFLSTI_CLUSTER_LDAP_FILTER},\"onthefly_register\":${EPFLSTI_CLUSTER_LDAP_REG},\"attr_login\":\"${EPFLSTI_CLUSTER_LDAP_ATT_LOGIN}\", \
  \"attr_firstname\":\"${EPFLSTI_CLUSTER_LDAP_ATT_FIRST}\",\"attr_lastname\":\"${EPFLSTI_CLUSTER_LDAP_ATT_LAST}\", \
  \"attr_mail\":\"${EPFLSTI_CLUSTER_LDAP_ATT_MAIL}\",\"attr_photo\":${EPFLSTI_CLUSTER_LDAP_ATT_PHOTO}}}" \
   -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" http://${EPFLSTI_CLUSTER_FOREMAN_IP}/api/auth_source_ldaps)

echo "$C_LDAP_AUTH"
echo "-- ${EPFLSTI_CLUSTER_LDAP_SRC_NAME} is created with ID ---------------------------------------------"
AUTH_SRC_ID=$(echo $C_LDAP_AUTH | grep -Po '"id":.*?[^\\]",' | cut -d, -f1 | cut -d: -f2)
echo $AUTH_SRC_ID


# Create a user group
# 	http://theforeman.org/api/apidoc/v2/usergroups.html
C_USER_GROUP=$(curl -s -u ${EPFLSTI_CLUSTER_USER}:${EPFLSTI_CLUSTER_PASS} -X POST -d \
  "{\"usergroup\": {\"name\": \"${EPFLSTI_CLUSTER_AUTH_GRP_NAME}\",\"admin\":${EPFLSTI_CLUSTER_AUTH_GRP_ADMIN}}}" \
   -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" http://${EPFLSTI_CLUSTER_FOREMAN_IP}/api/usergroups)

echo "$C_USER_GROUP"
echo "-- ${EPFLSTI_CLUSTER_AUTH_GRP_NAME} is created with ID --------------------------------------------"
USR_GRP_ID=$(echo $C_USER_GROUP | grep -Po '"id":.*?[^\\]",' | cut -d, -f1 | cut -d: -f2)
echo $USR_GRP_ID


# Create external usergroup linked to a usergroup
# 	http://theforeman.org/api/apidoc/v2/external_usergroups.html
C_EX_GROUP=$(curl -s -u ${EPFLSTI_CLUSTER_USER}:${EPFLSTI_CLUSTER_PASS} -X POST -d "{\"external_usergroup\": {\"name\": \"${EPFLSTI_CLUSTER_AUTH_EXT_GRP}\", \"auth_source_id\":$AUTH_SRC_ID}}" \
  -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" http://${EPFLSTI_CLUSTER_FOREMAN_IP}/api/usergroups/$USR_GRP_ID/external_usergroups)
echo "$C_EX_GROUP"
echo "--------------------------------------------------------------------------------"
echo "Now test it on http://${EPFLSTI_CLUSTER_FOREMAN_IP} "


# Role Begginer Administrator creation
# curl -i -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" -u admin http://${EPFLSTI_CLUSTER_FOREMAN_IP}/api/roles/
# {"name":"Beginner administrator","id":14,"builtin":0,"filters":[{"id":153},{"id":154},{"id":155},{"id":156},{"id":157},{"id":158},{"id":159},{"id":160},{"id":161},{"id":162},{"id":163},{"id":164},{"id":165},{"id":166},{"id":167},{"id":168},{"id":169},{"id":170},{"id":171},{"id":172},{"id":173},{"id":174},{"id":175},{"id":176}]}%
# Provisioning setup
# curl -i -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" -u admin http://${EPFLSTI_CLUSTER_FOREMAN_IP}/api/roles/10
# {"name":"Provisioning setup","id":10,"builtin":0,"filters":[{"id":118}]}

#
# Create STI-Smart-Admin role
# http://theforeman.org/api/apidoc/v2/roles.html

#
# WTF roles have differents ID on two installations :(
#
echo "-- Creating the STI-Smart-Admin role -------------------------------------------"
C_ROLES=$(curl -s -u ${EPFLSTI_CLUSTER_USER}:${EPFLSTI_CLUSTER_PASS} -X POST -d "{\"role\":{\"name\": \
  \"${EPFLSTI_CLUSTER_ROLE_NAME}\",\"filters\":[{\"id\":XXXX},{\"id\":XXXX},{\"id\":XXXX},{\"id\":XXXX}]}}" -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" http://${EPFLSTI_CLUSTER_FOREMAN_IP}/api/roles)

echo "$C_ROLES"
