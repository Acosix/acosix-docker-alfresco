#!/bin/bash

set -euo pipefail

DEBUG=${DEBUG:=false}

REPOSITORY_HOST=${REPOSITORY_HOST:=localhost}
REPOSITORY_PORT=${REPOSITORY_PORT:=80}
ACCESS_REPOSITORY_VIA_SSL=${ACCESS_REPOSITORY_VIA_SSL:=false}
REPOSITORY_SSL_PORT=${REPOSITORY_SSL_PORT:=443}

PUBLIC_REPOSITORY_HOST=${PUBLIC_REPOSITORY_HOST:-$REPOSITORY_HOST}
PUBLIC_REPOSITORY_PORT=${PUBLIC_REPOSITORY_PORT:-$REPOSITORY_PORT}
ACCESS_PUBLIC_REPOSITORY_VIA_SSL=${ACCESS_PUBLIC_REPOSITORY_VIA_SSL:-$ACCESS_REPOSITORY_VIA_SSL}
PUBLIC_REPOSITORY_SSL_PORT=${PUBLIC_REPOSITORY_SSL_PORT:-$REPOSITORY_SSL_PORT}

PROXY_NAME=${PROXY_NAME:=localhost}
PROXY_PORT=${PROXY_PORT:=80}
PROXY_SSL_PORT=${PROXY_SSL_PORT:=443}
LOCAL_PORT=${LOCAL_PORT:-8080}
LOCAL_SSL_PORT=${LOCAL_SSL_PORT:-8081}
PUBLIC_SHARE_HOST=${PUBLIC_SHARE_HOST:-${PROXY_NAME}}
PUBLIC_SHARE_PORT=${PUBLIC_SHARE_PORT:-${PROXY_PORT}}
PUBLIC_SHARE_SSL_PORT=${PUBLIC_SHARE_SSL_PORT:-${PROXY_SSL_PORT}}

KEYSTORE_PASSWORD=${KEYSTORE_PASSWORD:=alfresco-system}
TRUSTSTORE_PASSWORD=${TRUSTSTORE_PASSWORD:=password}

# TODO Kerberos and other global config
ACTIVATE_SSO=${ACTIVATE_SSO:=false}

if [ ! -f '/var/lib/tomcat8/.shareInitDone' ]
then
   
   sed -i "s/%DEBUG%/${DEBUG}/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   if [[ $DEBUG == true ]]
   then
      sed -i "s/%MODE%/development/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   else
      sed -i "s/%MODE%/production/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   fi
   
   sed -i "s/%REPOSITORY_HOST%/${REPOSITORY_HOST}/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   sed -i "s/%REPOSITORY_PORT%/${REPOSITORY_PORT}/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   sed -i "s/%REPOSITORY_SSL_PORT%/${REPOSITORY_SSL_PORT}/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   
   sed -i "s/%PUBLIC_REPOSITORY_HOST%/${PUBLIC_REPOSITORY_HOST}/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   sed -i "s/%PUBLIC_REPOSITORY_PORT%/${PUBLIC_REPOSITORY_PORT}/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   sed -i "s/%PUBLIC_REPOSITORY_SSL_PORT%/${PUBLIC_REPOSITORY_SSL_PORT}/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   
   PUBLIC_SHARE_HOST_PATTERN=`echo $PUBLIC_SHARE_HOST | sed -e "s/\./\\\./g"`
   sed -i "s/%PUBLIC_SHARE_HOST_PATTERN%/${PUBLIC_SHARE_HOST_PATTERN}/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   if [[ $PUBLIC_SHARE_PORT != 80 || $PUBLIC_SHARE_SSL_PORT != 443 ]]
   then
      sed -i "s/%PUBLIC_SHARE_PORT_PATTERN%/(:(${PUBLIC_SHARE_PORT}|${PUBLIC_SHARE_SSL_PORT}))?/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   else
      sed -i "s/%PUBLIC_SHARE_PORT_PATTERN%//g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   fi
   sed -i "s/%LOCAL_PORT_PATTERN%/(:(${LOCAL_PORT}|${LOCAL_SSL_PORT}))?/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   
   sed -i "s/%KEYSTORE_PASSWORD%/${KEYSTORE_PASSWORD}/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   sed -i "s/%TRUSTSTORE_PASSWORD%/${TRUSTSTORE_PASSWORD}/g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml

   if [[ $ACCESS_REPOSITORY_VIA_SSL == true ]]
   then
      sed -i "s/<!--%ACCESS_REPOSITORY_VIA_SSL%//g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
      sed -i "s/%ACCESS_REPOSITORY_VIA_SSL%-->//g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
      
      if [[ $ACTIVATE_SSO == true ]]
      then
         sed -i "s/<!--%ACTIVATE_SSO_VIA_SSL%//g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
         sed -i "s/%ACTIVATE_SSO_VIA_SSL%-->//g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
      fi
   fi
   
   if [[ $ACTIVATE_SSO == true ]]
   then
      sed -i "s/<!--%ACTIVATE_SSO%//g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
      sed -i "s/%ACTIVATE_SSO%-->//g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   fi
   
   if [[ $ACCESS_PUBLIC_REPOSITORY_VIA_SSL == true ]]
   then
      sed -i "s/<!--%ACCESS_PUBLIC_REPOSITORY_VIA_SSL%//g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
      sed -i "s/%ACCESS_PUBLIC_REPOSITORY_VIA_SSL%-->//g" /srv/alfresco/config/alfresco/web-extension/share-config-custom.xml
   fi

   # make sure we own webapps in case it was mounted / externally modified
   chown tomcat8:tomcat8 /var/lib/tomcat8/webapps

   # check / build share.war before processing of env config because we need to modify files shipped with it
   if [ ! -f '/var/lib/tomcat8/webapps/share.war' ]
   then
      if [[ -d '/srv/alfresco/defaultArtifacts' ]]
      then
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

   CUSTOM_APPENDER_LIST=''

   LOG4J_FILE=''
   if [ -f '/srv/alfresco/config/alfresco/web-extension/dev-log4j.properties' ]
   then
      LOG4J_FILE='/srv/alfresco/config/alfresco/web-extension/dev-log4j.properties'
   else
      # unzip Log4J config file since we cannot use a dev-log4j.properties with Share
      unzip -qq /var/lib/tomcat8/webapps/share.war WEB-INF/classes/log4j.properties -d /tmp/share
      # fix default configs
      sed -i 's/File=share\.log/File=\${catalina.base}\/logs\/share.log/' /tmp/share/WEB-INF/classes/log4j.properties
      sed -i 's/yyyy-MM-dd HH:mm:ss.SSS/ISO8601/' /tmp/share/WEB-INF/classes/log4j.properties

      LOG4J_FILE='/tmp/share/WEB-INF/classes/log4j.properties'
   fi

   # otherwise for will also cut on whitespace
   IFS=$'\n'
   for i in `env`
   do
      if [[ $i == GLOBAL_* && -f '/srv/alfresco/config/share-global.properties' ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         value=`echo "$i" | cut -d '=' -f 2-`
         
         if grep --quiet "^${key}=" /srv/alfresco/config/share-global.properties; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^${key}=.*/${key}=${value}/" /srv/alfresco/config/share-global.properties
         else
            echo "${key}=${value}" >> /srv/alfresco/config/share-global.properties
         fi
      fi
      
      if [[ $i == LOG4J-APPENDER_* ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         appenderName=`echo $key | cut -d '.' -f 1`
         value=`echo "$i" | cut -d '=' -f 2-`
         if grep --quiet "^${key}=" $LOG4J_FILE; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^log4j\.appender\.${key}=.*/log4j.appender.${key}=${value}/" $LOG4J_FILE
         else
            echo "log4j.appender.${key}=${value}" >> $LOG4J_FILE
         fi
         
         if [[ ! $CUSTOM_APPENDER_LIST =~ "^,([^,]+,)*${appenderName}(,[^,]+)*$" ]]
         then
            CUSTOM_APPENDER_LIST="${CUSTOM_APPENDER_LIST},${appenderName}"
         fi
      fi
      
      if [[ $i == LOG4J-LOGGER_* ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         value=`echo "$i" | cut -d '=' -f 2-`
         if grep --quiet "^${key}=" $LOG4J_FILE; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^log4j\.logger\.${key}=.*/log4j.logger.${key}=${value}/" $LOG4J_FILE
         else
            echo "log4j.logger.${key}=${value}" >> $LOG4J_FILE
         fi
      fi

      if [[ $i == LOG4J-ADDITIVITY_* ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         value=`echo "$i" | cut -d '=' -f 2-`
         if grep --quiet "^${key}=" $LOG4J_FILE; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^log4j\.additivity\.${key}=.*/log4j.additivity.${key}=${value}/" $LOG4J_FILE
         else
            echo "log4j.additivity.${key}=${value}" >> $LOG4J_FILE
         fi
      fi
   done

   if [[ $LOG4J_FILE == /tmp/share/WEB-INF/classes/log4j.properties ]]
   then
      sed -i "s/rootLogger=error, Console, File/rootLogger=error, File${CUSTOM_APPENDER_LIST}/" $LOG4J_FILE
      # re-zip share.war (after logging config updates)
      cd /tmp/share
      zip -r /var/lib/tomcat8/webapps/share.war .
      cd /
      rm -rf /tmp/share
   else
      sed -i "s/rootLogger=(.+)/rootLogger=\1${CUSTOM_APPENDER_LIST}/" $LOG4J_FILE
   fi

   # Share has issues when WAR files are not unpacked
   sed -i 's/unpackWARs="false"/unpackWARs="true"/' /etc/tomcat8/server.xml
   
   touch /var/lib/tomcat8/.shareInitDone
fi