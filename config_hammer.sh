#!/bin/bash
#
# Configure Foreman for an openstack-sti master
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

# Get auth_source_info
echo "-- Auth Source Info ------------------------------------------------------------"
curl -i -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" -u ${OSSTIIT_USER}:${OSSTIIT_PASS} http://${OSSTIIT_FOREMAN_IP}/api/auth_source_ldaps


# Create LDAP authentification source
#	http://theforeman.org/api/apidoc/v2/auth_source_ldaps.html
echo "-- Creating the LDAP auth source -----------------------------------------------"
C_LDAP_AUTH=$(curl -s -u ${OSSTIIT_USER}:${OSSTIIT_PASS} -X POST -d "{\"auth_source_ldap\":{\"name\": \
  \"${OSSTIIT_AUTH_SRC_NAME}\",\"host\": \"${OSSTIIT_LDAP_HOST}\",\"tls\":${OSSTIIT_LDAP_TLS}, \
  \"port\":${OSSTIIT_LDAP_PORT},\"server_type\":\"${OSSTIIT_LDAP_TYPE}\",\"account\":${OSSTIIT_LDAP_USER}, \
  \"account_password\":${OSSTIIT_LDAP_PASS},\"base_dn\":\"${OSSTIIT_LDAP_BASE}\",\"groups_base\":\"${OSSTIIT_LDAP_BASE}\", \
  \"ldap_filter\":${OSSTIIT_LDAP_FILTER},\"onthefly_register\":${OSSTIIT_LDAP_REG},\"attr_login\":\"${OSSTIIT_LDAP_ATT_LOGIN}\", \
  \"attr_firstname\":\"${OSSTIIT_LDAP_ATT_FIRST}\",\"attr_lastname\":\"${OSSTIIT_LDAP_ATT_LAST}\", \
  \"attr_mail\":\"${OSSTIIT_LDAP_ATT_MAIL}\",\"attr_photo\":${OSSTIIT_LDAP_ATT_PHOTO}}}" \
   -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" http://${OSSTIIT_FOREMAN_IP}/api/auth_source_ldaps)

echo "$C_LDAP_AUTH"
echo "-- ${OSSTIIT_LDAP_SRC_NAME} is created with ID ---------------------------------------------"
AUTH_SRC_ID=$(echo $C_LDAP_AUTH | grep -Po '"id":.*?[^\\]",' | cut -d, -f1 | cut -d: -f2)
echo $AUTH_SRC_ID


# Create a user group
# 	http://theforeman.org/api/apidoc/v2/usergroups.html
C_USER_GROUP=$(curl -s -u ${OSSTIIT_USER}:${OSSTIIT_PASS} -X POST -d \
  "{\"usergroup\": {\"name\": \"${OSSTIIT_AUTH_GRP_NAME}\",\"admin\":${OSSTIIT_AUTH_GRP_ADMIN}}}" \
   -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" http://${OSSTIIT_FOREMAN_IP}/api/usergroups)

echo "$C_USER_GROUP"
echo "-- ${OSSTIIT_AUTH_GRP_NAME} is created with ID --------------------------------------------"
USR_GRP_ID=$(echo $C_USER_GROUP | grep -Po '"id":.*?[^\\]",' | cut -d, -f1 | cut -d: -f2)
echo $USR_GRP_ID


# Create external usergroup linked to a usergroup
# 	http://theforeman.org/api/apidoc/v2/external_usergroups.html
C_EX_GROUP=$(curl -s -u ${OSSTIIT_USER}:${OSSTIIT_PASS} -X POST -d "{\"external_usergroup\": {\"name\": \"${OSSTIIT_AUTH_EXT_GRP}\", \"auth_source_id\":$AUTH_SRC_ID}}" \
  -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" http://${OSSTIIT_FOREMAN_IP}/api/usergroups/$USR_GRP_ID/external_usergroups)
echo "$C_EX_GROUP"
echo "--------------------------------------------------------------------------------"
echo "Now test it on http://${OSSTIIT_FOREMAN_IP} "


# Role Begginer Administrator creation
# curl -i -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" -u admin http://${OSSTIIT_FOREMAN_IP}/api/roles/
# {"name":"Beginner administrator","id":14,"builtin":0,"filters":[{"id":153},{"id":154},{"id":155},{"id":156},{"id":157},{"id":158},{"id":159},{"id":160},{"id":161},{"id":162},{"id":163},{"id":164},{"id":165},{"id":166},{"id":167},{"id":168},{"id":169},{"id":170},{"id":171},{"id":172},{"id":173},{"id":174},{"id":175},{"id":176}]}%
# Provisioning setup
# curl -i -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" -u admin http://${OSSTIIT_FOREMAN_IP}/api/roles/10
# {"name":"Provisioning setup","id":10,"builtin":0,"filters":[{"id":118}]}

#
# Create STI-Smart-Admin role
# http://theforeman.org/api/apidoc/v2/roles.html

#
# WTF roles have differents ID on two installations :(
#
echo "-- Creating the STI-Smart-Admin role -------------------------------------------"
C_ROLES=$(curl -s -u ${OSSTIIT_USER}:${OSSTIIT_PASS} -X POST -d "{\"role\":{\"name\": \
  \"${OSSTIIT_ROLE_NAME}\",\"filters\":[{\"id\":XXXX},{\"id\":XXXX},{\"id\":XXXX},{\"id\":XXXX}]}}" -H 'Accept:version=2' -H "Content-Type:application/json" -H "Accept:application/json" http://${OSSTIIT_FOREMAN_IP}/api/roles)

echo "$C_ROLES"
