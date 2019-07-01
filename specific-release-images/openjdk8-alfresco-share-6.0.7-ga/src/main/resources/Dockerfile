FROM ${docker.from.id}:${docker.from.version}

COPY *.war *.amp *.jar /tmp/

ENV MAVEN_REQUIRED_ARTIFACTS=org.orderofthebee.support-tools:support-tools-share:amp:1.0.0.0,de.fmaul:javascript-console-share:amp:0.6

LABEL vendor="${docker.labels.vendor}" \
   ${docker.labels.namespace}.version="${project.version.majorVersion}.${project.version.minorVersion}.${project.version.incrementalVersion}" \
   ${docker.labels.namespace}.is-beta="" \
   ${docker.labels.namespace}.is-production="" \
   ${docker.labels.namespace}.release-date="${docker.labels.release-date}" \
   ${docker.labels.namespace}.maintainer="${docker.labels.maintainer}"