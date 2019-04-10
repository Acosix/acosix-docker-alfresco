#!/bin/bash

set -euo pipefail

file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo >&2 "Error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(< "${!fileVar}")"
    fi
    unset "$fileVar"
    echo "$val"
}

DB_USER=${DB_USER:=alfresco}
DB_PW=${DB_PW:=alfresco}
DB_NAME=${DB_NAME:=alfresco}
DB_HOST=${DB_HOST:=localhost}
DB_PORT=${DB_PORT:=-1}

POSTGRES_ENABLED=${POSTGRES_ENABLED:=false}
MYSQL_ENABLED=${MYSQL_ENABLED:=false}
DB2_ENABLED=${DB2_ENABLED:=false}
MSSQL_ENABLED=${MSSQL_ENABLED:=false}
ORACLE_ENABLED=${ORACLE_ENABLED:=false}

ENABLE_SSL_PROXY=${ENABLE_SSL_PROXY:=false}
PROXY_NAME=${PROXY_NAME:=localhost}
PROXY_PORT=${PROXY_PORT:=80}
PROXY_SSL_PORT=${PROXY_SSL_PORT:=443}
LOCAL_PORT=${LOCAL_PORT:-8080}
LOCAL_SSL_PORT=${LOCAL_SSL_PORT:-8081}

# _RAW are for HTTP(S) access directly to Tomcat without reverse proxy, only using Docker NAT
PROXY_NAME_RAW=${PROXY_NAME_RAW:-$PROXY_NAME}
PROXY_PORT_RAW=${PROXY_PORT_RAW:=8082}
PROXY_SSL_PORT_RAW=${PROXY_SSL_PORT_RAW:=8083}

ENABLE_SHARE_SSL_PROXY=${ENABLE_SHARE_SSL_PROXY:=false}
SHARE_PROXY_NAME=${SHARE_PROXY_NAME:=localhost}
SHARE_PROXY_PORT=${SHARE_PROXY_PORT:=80}
SHARE_PROXY_SSL_PORT=${SHARE_PROXY_SSL_PORT:=443}

SEARCH_SUBSYSTEM=${SEARCH_SUBSYSTEM:=solr6}
SOLR_HOST=${SOLR_HOST:=localhost}
SOLR_PORT=${SOLR_PORT:=80}
SOLR_SSL_PORT=${SOLR_SSL_PORT:=443}
ACCESS_SOLR_VIA_SSL=${ACCESS_SOLR_VIA_SSL:=false}

REQUIRED_ARTIFACTS=${MAVEN_REQUIRED_ARTIFACTS:=''}
PLATFORM_VERSION=${ALFRESCO_PLATFORM_VERSION:=5.2.g}
LEGACY_SUPPORT_TOOLS_INSTALLED=${ALFRESCO_SUPPORT_TOOLS_INSTALLED:=false}

INIT_KEYSTORE_FROM_DEFAULT=${INIT_KEYSTORE_FROM_DEFAULT:=true}

ALFRESCO_ADMIN_PASSWORD=$(file_env ALFRESCO_ADMIN_PASSWORD admin)

if [ ! -f '/var/lib/tomcat8/.alfrescoInitDone' ]
then
   echo "Starting Alfresco container initialisation" > /proc/1/fd/1
   if [ ! -d '/srv/alfresco/data' ]
   then
      echo "Data directory has not been provided / mounted" > /proc/1/fd/1
      exit 1
   fi

   if [ ! -d '/srv/alfresco/data/contentstore' ]
   then
      mkdir -p /srv/alfresco/data/contentstore
      mkdir -p /srv/alfresco/data/contentstore.deleted
   fi

   # always ensure tomcat8 user owns the contentstore data
   chown -R tomcat8:tomcat8 /srv/alfresco/data

   if [[ $POSTGRES_ENABLED == true ]]
   then
      if [[ $MYSQL_ENABLED == true || $DB2_ENABLED == true || $MSSQL_ENABLED == true || $ORACLE_ENABLED == true ]]
      then
         echo "Multiple types of database to use have been configured" > /proc/1/fd/1
         exit 1
      fi
      DB_ACT_KEY="#usePostgreSQL#"
      if [[ $DB_PORT == -1 ]]
      then
         DB_PORT=5432
      fi
      echo "Setting up to use PostgreSQL on port ${DB_PORT}" > /proc/1/fd/1
   elif [[ $MYSQL_ENABLED == true ]]
   then
      if [[ $DB2_ENABLED == true || $MSSQL_ENABLED == true || $ORACLE_ENABLED == true ]]
      then
         echo "Multiple types of database to use have been configured" > /proc/1/fd/1
         exit 1
      fi
      DB_ACT_KEY="#useMySQL#"
      if [[ $DB_PORT == -1 ]]
      then
         DB_PORT=3006
      fi
      echo "Setting up to use MySQL on port ${DB_PORT}" > /proc/1/fd/1
   elif [[ $DB2_ENABLED == true ]]
   then
      if [[ $MSSQL_ENABLED == true || $ORACLE_ENABLED == true ]]
      then
         echo "Multiple types of database to use have been configured" > /proc/1/fd/1
         exit 1
      fi
      DB_ACT_KEY="#useDB2#"
      if [[ $DB_PORT == -1 ]]
      then
         DB_PORT=50000
      fi
      echo "Setting up to use DB2 on port ${DB_PORT}" > /proc/1/fd/1
   elif [[ $MSSQL_ENABLED == true ]]
   then
      if [[ $ORACLE_ENABLED == true ]]
      then
         echo "Multiple types of database to use have been configured" > /proc/1/fd/1
         exit 1
      fi
      DB_ACT_KEY="#useMSSQL#"
      if [[ $DB_PORT == -1 ]]
      then
         DB_PORT=1433
      fi
      echo "Setting up to use MS SQL on port ${DB_PORT}" > /proc/1/fd/1
   elif [[ $ORACLE_ENABLED == true ]]
   then
      DB_ACT_KEY="#useOracle#"
      if [[ $DB_PORT == -1 ]]
      then
         DB_PORT=1521
      fi
      echo "Setting up to use Oracle on port ${DB_PORT}" > /proc/1/fd/1
   else
      echo "Type of database to use has not been configured" > /proc/1/fd/1
        exit 1
   fi
   sed -i "s/${DB_ACT_KEY}//g" /srv/alfresco/config/alfresco-global.properties

   sed -i "s/%DB_HOST%/${DB_HOST}/g" /srv/alfresco/config/alfresco-global.properties
   sed -i "s/%DB_PORT%/${DB_PORT}/g" /srv/alfresco/config/alfresco-global.properties
   sed -i "s/%DB_NAME%/${DB_NAME}/g" /srv/alfresco/config/alfresco-global.properties
   sed -i "s/%DB_USER%/${DB_USER}/g" /srv/alfresco/config/alfresco-global.properties
   sed -i "s/%DB_PW%/${DB_PW}/g" /srv/alfresco/config/alfresco-global.properties

   ALFRESCO_ADMIN_PASSWORD=`printf '%s' "$ALFRESCO_ADMIN_PASSWORD" | iconv -t utf16le | openssl md4`
   sed -i "s/%ADMIN_PW%/${ALFRESCO_ADMIN_PASSWORD}/g" /srv/alfresco/config/alfresco-global.properties

   sed -i "s/%SEARCH_SUBSYSTEM%/${SEARCH_SUBSYSTEM}/g" /srv/alfresco/config/alfresco-global.properties
   sed -i "s/%SOLR_HOST%/${SOLR_HOST}/g" /srv/alfresco/config/alfresco-global.properties
   sed -i "s/%SOLR_PORT%/${SOLR_PORT}/g" /srv/alfresco/config/alfresco-global.properties
   sed -i "s/%SOLR_SSL_PORT%/${SOLR_SSL_PORT}/g" /srv/alfresco/config/alfresco-global.properties
   
   if [[ $ACCESS_SOLR_VIA_SSL == true ]]
   then
      sed -i "s/%SOLR_COMMS%/https/g" /srv/alfresco/config/alfresco-global.properties
   else
      sed -i "s/%SOLR_COMMS%/none/g" /srv/alfresco/config/alfresco-global.properties
   fi

   if [[ $ENABLE_SSL_PROXY == true ]]
   then
      sed -i "s/%PROXY_PROTO%/https/g" /srv/alfresco/config/alfresco-global.properties
      sed -i "s/%PROXY_PORT%/${PROXY_SSL_PORT}/g" /srv/alfresco/config/alfresco-global.properties
   else
      sed -i "s/%PROXY_PROTO%/http/g" /srv/alfresco/config/alfresco-global.properties
      sed -i "s/%PROXY_PORT%/${PROXY_PORT}/g" /srv/alfresco/config/alfresco-global.properties
   fi

   if [[ $ENABLE_SHARE_SSL_PROXY == true ]]
   then
      sed -i "s/%SHARE_PROXY_PROTO%/https/g" /srv/alfresco/config/alfresco-global.properties
      sed -i "s/%SHARE_PROXY_PORT%/${SHARE_PROXY_SSL_PORT}/g" /srv/alfresco/config/alfresco-global.properties
   else
      sed -i "s/%SHARE_PROXY_PROTO%/http/g" /srv/alfresco/config/alfresco-global.properties
      sed -i "s/%SHARE_PROXY_PORT%/${SHARE_PROXY_PORT}/g" /srv/alfresco/config/alfresco-global.properties
   fi

   sed -i "s/%PROXY_NAME%/${PROXY_NAME}/g" /srv/alfresco/config/alfresco-global.properties
   sed -i "s/%SHARE_PROXY_NAME%/${SHARE_PROXY_NAME}/g" /srv/alfresco/config/alfresco-global.properties

   PUBLIC_REPO_HOST_PATTERN=`echo $PROXY_NAME | sed -e "s/\./\\\./g"`
   sed -i "s/%PUBLIC_REPO_HOST_PATTERN%/${PUBLIC_REPO_HOST_PATTERN}/g" /srv/alfresco/config/alfresco-global.properties
   if [[ $PROXY_PORT != 80 || $PROXY_SSL_PORT != 443 ]]
   then
      sed -i "s/%PUBLIC_REPO_PORT_PATTERN%/(:(${PROXY_PORT}|${PROXY_SSL_PORT}))?/g" /srv/alfresco/config/alfresco-global.properties
   else
      sed -i "s/%PUBLIC_REPO_PORT_PATTERN%//g" /srv/alfresco/config/alfresco-global.properties
   fi
   sed -i "s/%LOCAL_PORT_PATTERN%/(:(${LOCAL_PORT}|${LOCAL_SSL_PORT}))?/g" /srv/alfresco/config/alfresco-global.properties

   echo "Processing environment variables for alfresco-global.properties and dev-log4j.properties" > /proc/1/fd/1
   CUSTOM_APPENDER_LIST='';

   # otherwise for will also cut on whitespace
   IFS=$'\n'
   for i in `env`
   do
      value=`echo "$i" | cut -d '=' -f 2-`

      if [[ $i == GLOBAL_* ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`

         if grep --quiet "^${key}=" /srv/alfresco/config/alfresco-global.properties; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^${key}=.*/${key}=${value}/" /srv/alfresco/config/alfresco-global.properties
         else
            echo "${key}=${value}" >> /srv/alfresco/config/alfresco-global.properties
         fi

         if [[ $key == hibernate.default_schema ]]
         then
            sed -i "s/#useCustomSchema#//g" /srv/alfresco/config/alfresco-global.properties
         fi

      elif [[ $i == LOG4J-APPENDER_* ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         appenderName=`echo $key | cut -d '.' -f 1`

         if grep --quiet "^${key}=" /srv/alfresco/config/alfresco/extension/dev-log4j.properties; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^log4j\.appender\.${key}=.*/log4j.appender.${key}=${value}/" /srv/alfresco/config/alfresco/extension/dev-log4j.properties
         else
            echo "log4j.appender.${key}=${value}" >> /srv/alfresco/config/alfresco/extension/dev-log4j.properties
         fi

         if [[ ! $CUSTOM_APPENDER_LIST =~ "^,([^,]+,)*${appenderName}(,[^,$]+)*$" ]]
         then
            CUSTOM_APPENDER_LIST="${CUSTOM_APPENDER_LIST},${appenderName}"
         fi

      elif [[ $i == LOG4J-LOGGER_* ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`

         if grep --quiet "^${key}=" /srv/alfresco/config/alfresco/extension/dev-log4j.properties; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^log4j\.logger\.${key}=.*/log4j.logger.${key}=${value}/" /srv/alfresco/config/alfresco/extension/dev-log4j.properties
         else
            echo "log4j.logger.${key}=${value}" >> /srv/alfresco/config/alfresco/extension/dev-log4j.properties
         fi

      elif [[ $i == LOG4J-ADDITIVITY_* ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`

         if grep --quiet "^${key}=" /srv/alfresco/config/alfresco/extension/dev-log4j.properties; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^log4j\.additivity\.${key}=.*/log4j.additivity.${key}=${value}/" /srv/alfresco/config/alfresco/extension/dev-log4j.properties
         else
            echo "log4j.additivity.${key}=${value}" >> /srv/alfresco/config/alfresco/extension/dev-log4j.properties
         fi
      fi
   done
   sed -i "s/#customAppenderList#/${CUSTOM_APPENDER_LIST}/" /srv/alfresco/config/alfresco/extension/dev-log4j.properties

   # either the module is installed explicitly, we have an Enterprise Edition version, or a specific flag is set
   if [[ $LEGACY_SUPPORT_TOOLS_INSTALLED == true || $REQUIRED_ARTIFACTS =~ '^(.+,)*alfresco-support-tools(,.+)*$' || $PLATFORM_VERSION =~ '^(5\.[2-9]\.\d(\.d)?|[6-9]\.\d\.\d(\.d)?)$' ]]
   then
      sed -i "s/#withAlfrescoSupportTools#//g" /srv/alfresco/config/alfresco/extension/dev-log4j.properties
   else
      sed -i "s/#withoutAlfrescoSupportTools#//g" /srv/alfresco/config/alfresco/extension/dev-log4j.properties
   fi

   if [ ! -f '/var/lib/tomcat8/webapps/alfresco.war' ]
   then
      echo "Preparing Repository WARs (including modules)" > /proc/1/fd/1
      if [[ -d '/srv/alfresco/defaultArtifacts' ]]
      then
         echo "Using default artifacts: $(ls -A /srv/alfresco/defaultArtifacts)" > /proc/1/fd/1
         # in case folder is empty we have to suppress error code
         cp /srv/alfresco/defaultArtifacts/* /tmp/ 2>/dev/null || :
      fi
      jjs -scripting /var/lib/tomcat8/prepareWarFiles.js -- /tmp
      mv /tmp/*.war /var/lib/tomcat8/webapps/

      if [[ ! -z "$(ls -A /tmp/*.jar)" ]]
      then
         mv /tmp/*.jar /srv/alfresco/modules/
      fi

      rm -f /tmp/*.jar /tmp/*.amp /tmp/*.war*
   fi

   # fixup bundled log4j.properties to use proper logfile path (startup doesn't immediately pick up dev-log4j.properties)
   unzip -qq /var/lib/tomcat8/webapps/alfresco.war WEB-INF/classes/log4j.properties -d /tmp/alfresco
   sed -i 's/File=alfresco\.log/File=\${catalina.base}\/logs\/alfresco.log/' /tmp/alfresco/WEB-INF/classes/log4j.properties
   sed -i 's/yyyy-MM-dd HH:mm:ss.SSS/ISO8601/' /tmp/alfresco/WEB-INF/classes/log4j.properties
   sed -i 's/%d{yyyy-MM-dd} %d{ABSOLUTE}/%d{ISO8601}/' /tmp/alfresco/WEB-INF/classes/log4j.properties
   sed -i 's/log4j\.rootLogger=error, Console, File/log4j.rootLogger=error, File/' /tmp/alfresco/WEB-INF/classes/log4j.properties
   cd /tmp/alfresco
   zip -r /var/lib/tomcat8/webapps/alfresco.war .
   cd /
   rm -rf /tmp/alfresco

   if [[ $INIT_KEYSTORE_FROM_DEFAULT == true && -z "$(ls -A /srv/alfresco/keystore)" ]]
   then
      echo "Initialising keystore from default" > /proc/1/fd/1
      unzip -qq /var/lib/tomcat8/webapps/alfresco.war WEB-INF/lib/alfresco-repository-*.jar -d /tmp/alfresco
      REPO_JAR=$(ls -A /tmp/alfresco/WEB-INF/lib/alfresco-repository-*.jar)
      unzip -qq "${REPO_JAR}" alfresco/keystore/* -d /tmp/alfresco-repo
      cp /tmp/alfresco-repo/alfresco/keystore/* /srv/alfresco/keystore/
      rm -rf /tmp/alfresco /tmp/alfresco-repo
   fi

   if [[ -f '/srv/alfresco/keystore/keystore' && -f '/srv/alfresco/keystore/keystore-passwords.properties' ]]
   then
      echo "Referencing custom keystore" > /proc/1/fd/1
      sed -i "/^#useCustomKeystore#/d" /srv/alfresco/config/alfresco-global.properties
   fi

   echo "Setting up raw HTTP connector" > /proc/1/fd/1
   sed -i '/<Engine/i <Connector executor="tomcatThreadPool" port="8082" protocol="HTTP/1.1"' /etc/tomcat8/server.xml
   sed -i '/<Engine/i connectionTimeout="20000" redirectPort="%PROXY_SSL_PORT_RAW%" URIEncoding="UTF-8" maxHttpHeaderSize="32768"' /etc/tomcat8/server.xml
   sed -i '/<Engine/i proxyName="%PROXY_NAME_RAW%" proxyPort="%PROXY_PORT_RAW%" />' /etc/tomcat8/server.xml

   if [[ -f '/srv/alfresco/keystore/ssl.keystore' && -f '/srv/alfresco/keystore/ssl-keystore-passwords.properties' && -f '/srv/alfresco/keystore/ssl.truststore' && -f '/srv/alfresco/keystore/ssl-truststore-passwords.properties' ]]
   then
      echo "Setting up raw SSL connector and Tomcat users" > /proc/1/fd/1

      SSL_KEYSTORE_PASSWORD=$(grep 'keystore.password=' /srv/alfresco/keystore/ssl-keystore-passwords.properties | sed -r 's/keystore\.password=(.+)/\1/')
      SSL_TRUSTSTORE_PASSWORD=$(grep 'keystore.password=' /srv/alfresco/keystore/ssl-truststore-passwords.properties | sed -r 's/keystore\.password=(.+)/\1/')

      sed -i '/<Engine/i <Connector executor="tomcatThreadPool" port="8083" protocol="org.apache.coyote.http11.Http11Protocol" SSLEnabled="true"' /etc/tomcat8/server.xml
      sed -i '/<Engine/i proxyName="%PROXY_NAME_RAW%" proxyPort="%PROXY_SSL_PORT_RAW%"' /etc/tomcat8/server.xml
      sed -i '/<Engine/i scheme="https" secure="true"' /etc/tomcat8/server.xml
      sed -i "/<Engine/i keystoreFile=\"/srv/alfresco/keystore/ssl.keystore\" keystorePass=\"${SSL_KEYSTORE_PASSWORD}\" keystoreType=\"JCEKS\"" /etc/tomcat8/server.xml
      sed -i "/<Engine/i truststoreFile=\"/srv/alfresco/keystore/ssl.truststore\" truststorePass=\"${SSL_TRUSTSTORE_PASSWORD}\" truststoreType=\"JCEKS\"" /etc/tomcat8/server.xml
      sed -i '/<Engine/i clientAuth="want" sslProtocol="TLS" connectionTimeout="240000"' /etc/tomcat8/server.xml
      sed -i '/<Engine/i URIEncoding="UTF-8" maxHttpHeaderSize="32768" allowUnsafeLegacyRenegotiation="true" />' /etc/tomcat8/server.xml
      sed -i "s/%SSL_KEYSTORE_PASSWORD%/${SSL_KEYSTORE_PASSWORD}/" /etc/tomcat8/server.xml
      sed -i "s/%SSL_TRUSTSTORE_PASSWORD%/${SSL_TRUSTSTORE_PASSWORD}/" /etc/tomcat8/server.xml

      sed -i '/<\/tomcat-users>/i <user username="CN=Alfresco Repository Client, OU=Unknown, O=Alfresco Software Ltd., L=Maidenhead, ST=UK, C=GB" roles="repoclient" password="null" />' /etc/tomcat8/tomcat-users.xml
   fi
   
   sed -i "s/%PROXY_NAME_RAW%/${PROXY_NAME_RAW}/" /etc/tomcat8/server.xml
   sed -i "s/%PROXY_PORT_RAW%/${PROXY_PORT_RAW}/" /etc/tomcat8/server.xml
   sed -i "s/%PROXY_SSL_PORT_RAW%/${PROXY_SSL_PORT_RAW}/" /etc/tomcat8/server.xml

   # Alfresco (since 6.0 / in Tomcat 8) has issues when WAR files are not unpacked
   sed -i 's/unpackWARs="false"/unpackWARs="true"/' /etc/tomcat8/server.xml

   echo "Completed Alfresco container initialisation" > /proc/1/fd/1
   touch /var/lib/tomcat8/.alfrescoInitDone
fi