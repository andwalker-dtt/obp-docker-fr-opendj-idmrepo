#!/usr/bin/env bash
# Set up a directory server.
#
# Copyright (c) 2016-2018 ForgeRock AS. Use of this source code is subject to the
# Common Development and Distribution License (CDDL) that can be found in the LICENSE file

#set -x

cd /opt/opendj

echo "Setting up $BASE_DN"

INIT_OPTION="--addBaseEntry"

# If NUMBER_SAMPLE_USERS is set AND we are the first node, then generate sample users.
if [[  -n "${NUMBER_SAMPLE_USERS}" && $HOSTNAME = *"0"* ]]; then
    INIT_OPTION="--sampleData ${NUMBER_SAMPLE_USERS}"
fi

echo "Base DN is ${BASE_DN}"
echo "FQDN is ${FQDN}"
echo "DIR_MANAGER_PW_FILE is ${DIR_MANAGER_PW_FILE}"
echo "KEYSTORE_PIN_FILE is ${KEYSTORE_PIN_FILE}"

# Setup directory server
./setup directory-server \
  --ldapPort 1389 \
  --enableStartTLS  \
  --adminConnectorPort 4444 \
  --enableStartTls \
  --ldapsPort 1636 \
  --httpPort 8080 --httpsPort 8443 \
  --baseDN "${BASE_DN}" \
  --hostname "${FQDN}" \
  --rootUserDN "cn=Directory Manager" \
  --rootUserPasswordFile "${DIR_MANAGER_PW_FILE}" \
  --monitorUserPasswordFile "${MONITOR_PW_FILE}" \
  --usePkcs12KeyStore "${KEYSTORE_FILE}" \
  --keyStorePasswordFile "${KEYSTORE_PIN_FILE}" \
  --certNickName "${SSL_CERT_ALIAS}" \
  --acceptLicense \
  --doNotStart \
   ${INIT_OPTION}  || (echo "Setup failed, will sleep for debugging"; sleep 10000)


echo "Set the global server id to $SERVER_ID"

bin/dsconfig  set-global-configuration-prop --set server-id:$SERVER_ID  --offline  --no-prompt


echo "Creating Default Trust Manager..."
./bin/dsconfig create-trust-manager-provider \
      --type file-based \
      --provider-name "Default Trust Manager" \
      --set enabled:true \
      --set trust-store-type:PKCS12 \
      --set trust-store-pin:\&{file:"${KEYSTORE_PIN_FILE}"} \
      --set trust-store-file:"${KEYSTORE_FILE}" \
      --offline \
      --no-prompt

echo "Configuring LDAP connection handler..."
./bin/dsconfig set-connection-handler-prop \
      --handler-name "LDAP" \
      --set "trust-manager-provider:Default Trust Manager" \
      --offline \
      --no-prompt

echo "Configuring LDAPS connection handler..."
./bin/dsconfig set-connection-handler-prop \
      --handler-name "LDAPS" \
      --set "trust-manager-provider:Default Trust Manager" \
      --offline \
      --no-prompt


# For development you may want to tune the disk thresholds. TODO: Make this configurable
bin/dsconfig  set-backend-prop \
    --backend-name userRoot  \
    --set "disk-low-threshold:2GB"  --set "disk-full-threshold:1GB"  \
    --offline \
    --no-prompt


# Load any optional LDIF files. $1 is the directory to load from
load_ldif() {

    # If any optional LDIF files are present, load them.
    ldif=$1

    if [ -d "$ldif" ]; then
        echo "Loading LDIF files in $ldif"
        for file in "${ldif}"/*.ldif;  do
            echo "Loading $file"
            # search + replace all placeholder variables. Naming conventions are from AM.
            sed -e "s/@BASE_DN@/$BASE_DN/"  \
                -e "s/@userStoreRootSuffix@/$BASE_DN/"  \
                -e "s/@DB_NAME@/$DB_NAME/"  \
                -e "s/@SM_CONFIG_ROOT_SUFFIX@/$BASE_DN/"  <${file}  >/tmp/file.ldif

            #cat /tmp/file.ldif
            echo bin/ldapmodify -D "cn=Directory Manager"  --continueOnError -h localhost -p 1389 -j ${DIR_MANAGER_PW_FILE} -f /tmp/file.ldif
            bin/ldapmodify -D "cn=Directory Manager"  --continueOnError -h localhost -p 1389 -j ${DIR_MANAGER_PW_FILE} -f /tmp/file.ldif
            # Note that currently these ldif files must be added with ldapmodify.
            #bin/import-ldif --offline -n userRoot -l /tmp/file.ldif --rejectFile /tmp/rejects.ldif
            #cat /tmp/rejects.ldif
          echo "  "
        done
    fi
}


# Load any optional ldif files. These fiiles need to be loaded with the server running.
bin/start-ds

# OpenIDM setup
./bin/dsconfig \
 create-schema-provider \
 --hostname localhost \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
 --provider-name "IDM managed/user Json Schema" \
 --type json-query-equality-matching-rule \
 --set enabled:true \
 --set case-sensitive-strings:false \
 --set ignore-white-space:true \
 --set matching-rule-name:caseIgnoreJsonQueryMatchManagedUser \
 --set matching-rule-oid:1.3.6.1.4.1.36733.2.3.4.1  \
 --set indexed-field:userName \
 --set indexed-field:givenName \
 --set indexed-field:sn \
 --set indexed-field:mail \
 --set indexed-field:accountStatus \
 --trustAll \
 --no-prompt

./bin/dsconfig \
 create-schema-provider \
 --hostname localhost \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
 --provider-name "IDM managed/role Json Schema" \
 --type json-query-equality-matching-rule \
 --set enabled:true \
 --set case-sensitive-strings:false \
 --set ignore-white-space:true \
 --set matching-rule-name:caseIgnoreJsonQueryMatchManagedRole \
 --set matching-rule-oid:1.3.6.1.4.1.36733.2.3.4.2  \
 --set indexed-field:"condition/**" \
 --set indexed-field:"temporalConstraints/**" \
 --trustAll \
 --no-prompt

./bin/dsconfig \
 create-schema-provider \
 --hostname localhost \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
 --provider-name "IDM Relationship Json Schema" \
 --type json-query-equality-matching-rule \
 --set enabled:true \
 --set case-sensitive-strings:false \
 --set ignore-white-space:true \
 --set matching-rule-name:caseIgnoreJsonQueryMatchRelationship \
 --set matching-rule-oid:1.3.6.1.4.1.36733.2.3.4.3  \
 --set indexed-field:firstResourceCollection \
 --set indexed-field:firstResourceId \
 --set indexed-field:firstPropertyName \
 --set indexed-field:secondResourceCollection \
 --set indexed-field:secondResourceId \
 --set indexed-field:secondPropertyName \
 --trustAll \
 --no-prompt

./bin/dsconfig \
  create-schema-provider \
  --hostname localhost \
  --port 4444 \
  --bindDN "cn=Directory Manager" \
  --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
  --provider-name "IDM Cluster Object Json Schema" \
  --type json-query-equality-matching-rule \
  --set enabled:true \
  --set case-sensitive-strings:false \
  --set ignore-white-space:true \
  --set matching-rule-name:caseIgnoreJsonQueryMatchClusterObject \
  --set matching-rule-oid:1.3.6.1.4.1.36733.2.3.4.4  \
  --set indexed-field:"timestamp" \
  --set indexed-field:"state" \
  --trustAll \
  --no-prompt

cp /opt/opendj/openidm.ldif db/schema/99-openidm.ldif

bin/stop-ds --restart

bin/dsconfig \
 create-backend-index \
 --hostname localhost \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
 --backend-name userRoot \
 --index-name fr-idm-managed-user-json \
 --set index-type:equality \
 --trustAll \
 --no-prompt

bin/dsconfig \
 create-backend-index \
 --hostname localhost \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
 --backend-name userRoot \
 --index-name fr-idm-managed-role-json \
 --set index-type:equality \
 --trustAll \
 --no-prompt

bin/dsconfig \
 create-backend-index \
 --hostname localhost \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
 --backend-name userRoot \
 --index-name fr-idm-relationship-json \
 --set index-type:equality \
 --trustAll \
 --no-prompt

bin/dsconfig \
 create-backend-index \
 --hostname localhost \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
 --backend-name userRoot \
 --index-name fr-idm-cluster-json \
 --set index-type:equality \
 --trustAll \
 --no-prompt

bin/dsconfig \
 create-backend-index \
 --hostname localhost \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
 --backend-name userRoot \
 --index-name fr-idm-json \
 --set index-type:equality \
 --trustAll \
 --no-prompt

bin/dsconfig \
 create-backend-index \
 --hostname localhost \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
 --backend-name userRoot \
 --index-name fr-idm-link-type \
 --set index-type:equality \
 --trustAll \
 --no-prompt

bin/dsconfig \
 create-backend-index \
 --hostname localhost \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
 --backend-name userRoot \
 --index-name fr-idm-link-firstid \
 --set index-type:equality \
 --trustAll \
 --no-prompt

bin/dsconfig \
 create-backend-index \
 --hostname localhost \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
 --backend-name userRoot \
 --index-name fr-idm-link-secondid \
 --set index-type:equality \
 --trustAll \
 --no-prompt

bin/dsconfig \
 create-backend-index \
 --hostname localhost \
 --port 4444 \
 --bindDN "cn=Directory Manager" \
 --bindPasswordFile "${DIR_MANAGER_PW_FILE}" \
 --backend-name userRoot \
 --index-name fr-idm-link-qualifier \
 --set index-type:equality \
 --trustAll \
 --no-prompt

# Load OpenIDM populate_users.ldif
load_ldif "${OBP_LDIF_DIRECTORY}"

bin/stop-ds

echo "Rebuilding indexes"
bin/rebuild-index --offline --baseDN "${BASE_DN}" --rebuildDegraded


# Run post install customization script if the user supplied one.
script="bootstrap/post-install.sh"

if [ -r "$script" ]; then
    echo "executing post install script $script"
    sh "$script"
fi


./bootstrap/log-redirect.sh


if [ -d data ]; then
    echo "Moving mutable directories to data/"
    # For now we need to most of the directories created by setup, including the "immutable" ones.
    # When we get full support for commons configuration we should revisit.
    for dir in db changelogDb config var import-tmp
    do
        echo "moving $dir to data/"
        # Use cp as it works across file systems.
        cp -r $dir data/$dir
        rm -fr $dir
    done
fi


for d in data/*
do
    echo "Creating symbolic link $d"
    ln -s $d
done
