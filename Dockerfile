# Google Cloud Container Registry - Andrew Walker
FROM gcr.io/deloitte-fr/docker-fr-opendj-6.0.0

ENV BOOTSTRAP=/opt/opendj/bootstrap/extensions/setup-idmrepo-directory.sh \
    OBP_LDIF_DIRECTORY=/opt/opendj/bootstrap/extensions/ldif \
    SECRET_PATH=/opt/opendj/secrets \
    DIR_MANAGER_PW_FILE=/opt/opendj/secrets/dirmanager.pw \
    MONITOR_PW_FILE=/opt/opendj/secrets/monitor.pw \
    KEYSTORE_FILE=/opt/opendj/secrets/keystore.pkcs12 \
    KEYSTORE_PIN_FILE=/opt/opendj/secrets/keystore.pin

COPY setup-idmrepo-directory.sh /opt/opendj/bootstrap/extensions/setup-idmrepo-directory.sh
COPY ldif /opt/opendj/bootstrap/extensions/ldif
COPY openidm/openidm.ldif /opt/opendj/

# Copy default secrets
COPY secrets/ /opt/opendj/secrets/

RUN chown -R forgerock:root /opt/opendj/bootstrap/extensions \
    && chmod +rwx /opt/opendj/bootstrap/extensions \
    && chmod a+x ${BOOTSTRAP}
