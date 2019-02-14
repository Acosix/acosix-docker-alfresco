FROM ${docker.from.id}:${docker.from.version}

# add prepared files that would be too awkward to handle via RUN / sed
COPY share-config-custom.xml share.xml share-logrotate.d initShare.sh prepareWarFiles.js share-ng.conf /tmp/

# apply our Alfresco Share default configurations
RUN mv /tmp/share-logrotate.d /etc/logrotate.d/share \
   && mkdir -p /srv/alfresco/config/alfresco/web-extension /srv/alfresco/modules /etc/tomcat8/Catalina/localhost \
   && mv /tmp/share-config-custom.xml /srv/alfresco/config/alfresco/web-extension/ \
   && mv /tmp/share.xml /etc/tomcat8/Catalina/localhost/ \
   && touch /var/lib/tomcat8/logs/.share-logrotate-dummy \
   && mv /tmp/prepareWarFiles.js /var/lib/tomcat8/ \
   && mv /tmp/share-ng.conf /etc/syslog-ng/conf.d/share-ng.conf \
   && mv /tmp/initShare.sh /etc/my_init.d/50_initShare.sh \
   && chmod +x /etc/my_init.d/50_initShare.sh

ENV MAVEN_REQUIRED_ARTIFACTS= \
   ALFRESCO_MMT_VERSION=6.0 \
   ALFRESCO_SHARE_VERSION=6.0.c \
   MAVEN_ACTIVE_REPOSITORIES=alfresco,alfresco_ee,central,ossrh \
   MAVEN_REPOSITORIES_central_URL=https://repo1.maven.org/maven2 \
   MAVEN_REPOSITORIES_alfresco_URL=https://artifacts.alfresco.com/nexus/content/groups/public \
   MAVEN_REPOSITORIES_alfresco_ee_URL=https://artifacts.alfresco.com/nexus/content/groups/private \
   MAVEN_REPOSITORIES_ossrh_URL=https://oss.sonatype.org/content/repositories/snapshots \
   JMX_RMI_PORT=5002

EXPOSE 8080 8081 5002

VOLUME ["/srv/alfresco/keystore", "/srv/alfresco/defaultArtifacts"]

LABEL vendor="${docker.labels.vendor}" \
   ${docker.labels.namespace}.version="${project.version.majorVersion}.${project.version.minorVersion}.${project.version.incrementalVersion}" \
   ${docker.labels.namespace}.is-beta="" \
   ${docker.labels.namespace}.is-production="" \
   ${docker.labels.namespace}.release-date="${docker.labels.release-date}" \
   ${docker.labels.namespace}.maintainer="${docker.labels.maintainer}"