#!/bin/bash

set -e

ENABLED_CORES=${ENABLED_CORES:=alfresco,archive}

SOLR_HOST=${SOLR_HOST:=localhost}
SOLR_PORT=${SOLR_PORT:=8983}

REPOSITORY_HOST=${REPOSITORY_HOST:=localhost}
REPOSITORY_PORT=${REPOSITORY_PORT:=80}
ACCESS_REPOSITORY_VIA_SSL=${ACCESS_REPOSITORY_VIA_SSL:=false}
REPOSITORY_SSL_PORT=${REPOSITORY_SSL_PORT:=443}

IFS=',' read -ra CORE_LIST <<< "$ENABLED_CORES"

# a sub image may pre-package ASS to keep the image light
if [ ! -d '/var/lib/alfresco-search-services' ]
then
   if [ -f '/srv/alfresco-search-services/downloadASS.js' ]
   then
      if [[ -d '/srv/alfresco-search-services/defaultArtifacts' ]]
      then
         echo "Using default artifacts: $(ls -A /srv/alfresco-search-services/defaultArtifacts)" > /proc/1/fd/1
         # in case folder is empty we have to suppress error code
         cp /srv/alfresco-search-services/defaultArtifacts/* /tmp/ 2>/dev/null || :
      fi

      echo "Download Alfresco Search Services" > /proc/1/fd/1
      jjs -scripting /srv/alfresco-search-services/downloadASS.js -- /tmp
   fi

   unzip -qq "/tmp/alfresco-search-services-*.zip" -d /var/lib/

   sed -i 's/^#SOLR_HOME=/SOLR_HOME=\/srv\/alfresco-search-services\/solrhome/' /var/lib/alfresco-search-services/solr.in.sh
   sed -i 's/^SOLR_LOGS_DIR=.*/SOLR_LOGS_DIR=\/var\/log\/alfresco-search-services/' /var/lib/alfresco-search-services/solr.in.sh
   sed -i 's/^LOG4J_PROPS=.*/LOG4J_PROPS=\/var\/lib\/alfresco-search-services\/logs\/log4j.properties/' /var/lib/alfresco-search-services/solr.in.sh
   sed -i '/-remove_old_solr_logs/d' /var/lib/alfresco-search-services/solr/bin/solr
   sed -i '/-archive_gc_logs/d' /var/lib/alfresco-search-services/solr/bin/solr
   sed -i '/-archive_console_logs/d' /var/lib/alfresco-search-services/solr/bin/solr
   sed -i '/-rotate_solr_logs/d' /var/lib/alfresco-search-services/solr/bin/solr
   sed -i '/set that as the rmi server hostname/,/fi/ s/SOLR_HOST/JMX_HOST/' /var/lib/alfresco-search-services/solr/bin/solr
   sed -i 's/rootLogger=WARN, file, CONSOLE/rootLogger=WARN, file/' /var/lib/alfresco-search-services/logs/log4j.properties
   sed -i 's/\.RollingFileAppender$/.DailyRollingFileAppender/' /var/lib/alfresco-search-services/logs/log4j.properties
   sed -i 's/MaxFileSize=4MB$/DatePattern='.'yyyy-MM-dd/' /var/lib/alfresco-search-services/logs/log4j.properties
   sed -i 's/MaxBackupIndex=9$/Append=true/' /var/lib/alfresco-search-services/logs/log4j.properties
   sed -i 's/yyyy-MM-dd HH:mm:ss.SSS/ISO8601/' /var/lib/alfresco-search-services/logs/log4j.properties
   mkdir -p /srv/alfresco-search-services/solrhome /srv/alfresco-search-services/contentstore /var/log/alfresco-search-services
   mv /var/lib/alfresco-search-services/solrhome/* /srv/alfresco-search-services/solrhome/
   rm -rf /var/lib/alfresco-search-services/solr/docs /var/lib/alfresco-search-services/solrhome
   chown -R ass:ass /var/lib/alfresco-search-services /srv/alfresco-search-services/solrhome /srv/alfresco-search-services/contentstore /var/log/alfresco-search-services

   # define additional parameters so that our initialisation will allow overriding them
   echo "#JMX_HOST=" >> /var/lib/alfresco-search-services/solr.in.sh
fi

if [ ! -f '/var/lib/alfresco-search-services/.assInitDone' ]
then
   sed -i 's/solr\.host=localhost/solr.host=%PUBLIC_SOLR_HOST%/' /srv/alfresco-search-services/solrhome/conf/shared.properties
   sed -i 's/#solr\.port=8983/solr.port=%PUBLIC_SOLR_PORT%/' /srv/alfresco-search-services/solrhome/conf/shared.properties
   sed -i "s/%PUBLIC_SOLR_HOST%/${SOLR_HOST}/g" /srv/alfresco-search-services/solrhome/conf/shared.properties
   sed -i "s/%PUBLIC_SOLR_PORT%/${SOLR_PORT}/g" /srv/alfresco-search-services/solrhome/conf/shared.properties

   CUSTOM_APPENDER_LIST=''

   # otherwise for will also cut on whitespace
   IFS=$'\n'
   for i in `env`
   do
      value=`echo "$i" | cut -d '=' -f 2-`
      if [[ $i == LOG4J-APPENDER_* ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         appenderName=`echo $key | cut -d '.' -f 1`
         if grep --quiet "^${key}=" /var/lib/alfresco-search-services/logs/log4j.properties; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^log4j\.appender\.${key}=.*/log4j.appender.${key}=${value}/" /var/lib/alfresco-search-services/logs/log4j.properties
         else
            echo "log4j.appender.${key}=${value}" >> /var/lib/alfresco-search-services/logs/log4j.properties
         fi

         if [[ ! $CUSTOM_APPENDER_LIST =~ "^,([^,]+,)*${appenderName}(,[^,$]+)*$" ]]
         then
            CUSTOM_APPENDER_LIST="${CUSTOM_APPENDER_LIST},${appenderName}"
         fi
      elif [[ $i == LOG4J-LOGGER_* ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         if grep --quiet "^${key}=" /var/lib/alfresco-search-services/logs/log4j.properties; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^log4j\.logger\.${key}=.*/log4j.logger.${key}=${value}/" /var/lib/alfresco-search-services/logs/log4j.properties
         else
            echo "log4j.logger.${key}=${value}" >> /var/lib/alfresco-search-services/logs/log4j.properties
         fi
      elif [[ $i == LOG4J-ADDITIVITY_* ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         if grep --quiet "^${key}=" /var/lib/alfresco-search-services/logs/log4j.properties; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^log4j\.additivity\.${key}=.*/log4j.additivity.${key}=${value}/" /var/lib/alfresco-search-services/logs/log4j.properties
         else
            echo "log4j.additivity.${key}=${value}" >> /var/lib/alfresco-search-services/logs/log4j.properties
         fi
      elif [[ ! -z $value ]]
      then
         # we only handle properties already defined in solr.in.sh - otherwise we'd end up adding arbitrary config not meant for SOLR
         key=`echo "$i" | cut -d '=' -f 1`
         DEF_COUNT=$(grep "$key=" /var/lib/alfresco-search-services/solr.in.sh | wc -l)
         if [[ DEF_COUNT -eq 1 ]]
         then
            echo "Processing environment variable $i" > /proc/1/fd/1
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^\s*#?\s*$key=.*/$key=$value/" /var/lib/alfresco-search-services/solr.in.sh
         elif [[ ! DEF_COUNT -eq 0 ]]
         then
            echo "Processing environment variable $i" > /proc/1/fd/1
            echo "$key=\"\${${key}} $value\"" >> /var/lib/alfresco-search-services/solr.in.sh
         fi
      fi
   done
   sed -i "s/rootLogger=WARN, file/rootLogger=WARN, file, ${CUSTOM_APPENDER_LIST}/" /var/lib/alfresco-search-services/logs/log4j.properties

   NEW_CORE_LIST=''
   for core in "${CORE_LIST[@]}"
   do
      if [[ ! -d "/srv/alfresco-search-services/coreConfigs/${core}" || ! -f "/srv/alfresco-search-services/coreConfigs/${core}/core.properties" ]]
      then
         echo "Setting up Alfresco Search Services core ${core}" > /proc/1/fd/1
         cp -r /srv/alfresco-search-services/solrhome/templates/rerank "/srv/alfresco-search-services/coreConfigs/${core}"
         echo "name=${core}" >> "/srv/alfresco-search-services/coreConfigs/${core}/core.properties"
         ln -s "/srv/alfresco-search-services/coreConfigs/${core}" "/srv/alfresco-search-services/solrhome/${core}"

         sed -i "s/#data\.dir\.root=.*/data.dir.root=\/srv\/alfresco-search-services\/index/" "/srv/alfresco-search-services/solrhome/${core}/conf/solrcore.properties"
         sed -i "s/#data\.dir\.store=.*/data.dir.store=${core}/" "/srv/alfresco-search-services/solrhome/${core}/conf/solrcore.properties"
         sed -i "s/host=.*/host=${REPOSITORY_HOST}/" "/srv/alfresco-search-services/solrhome/${core}/conf/solrcore.properties"
         sed -i "s/port=.*/port=${REPOSITORY_PORT}/" "/srv/alfresco-search-services/solrhome/${core}/conf/solrcore.properties"
         sed -i "s/port\.ssl=.*/port.ssl=${REPOSITORY_SSL_PORT}/" "/srv/alfresco-search-services/solrhome/${core}/conf/solrcore.properties"

         if [[ $ACCESS_REPOSITORY_VIA_SSL == true ]]
         then
            sed -i "s/secureComms=.*/secureComms=https/" "/srv/alfresco-search-services/solrhome/${core}/conf/solrcore.properties"
         fi

         if [[ ${core} == 'alfresco' ]]
         then
            sed -i "s/#alfresco\.stores=.*/alfresco.stores=workspace:\/\/SpacesStore/" "/srv/alfresco-search-services/solrhome/${core}/conf/solrcore.properties"
         fi
         if [[ ${core} == 'archive' ]]
         then
            sed -i "s/#alfresco\.stores=.*/alfresco.stores=archive:\/\/SpacesStore/" "/srv/alfresco-search-services/solrhome/${core}/conf/solrcore.properties"
         fi

         if [[ $NEW_CORE_LIST ]]
         then
            NEW_CORE_LIST="${NEW_CORE_LIST},${core}"
         else
            NEW_CORE_LIST=${core}
         fi
      elif [[ ! -d "/srv/alfresco-search-services/solrhome/${core}" ]]
      then
         echo "Linking existing Alfresco Search Services core ${core}" > /proc/1/fd/1
         ln -s "/srv/alfresco-search-services/coreConfigs/${core}" "/srv/alfresco-search-services/solrhome/${core}"
      fi
   done

   for i in `env`
   do
      if [[ $i == CORE_* ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         coreName=`echo $key | cut -d '.' -f 1`
         valueKey=`echo $key | cut -d '.' -f 2-`
         value=`echo "$i" | cut -d '=' -f 2-`

         # we only apply settings for core configs we created in this run
         if [[ $NEW_CORE_LIST =~ "^([^,]+,)*${coreName}(,[^,$]+)*$" ]]
         then
            if grep --quiet "^${key}=" "/srv/alfresco-search-services/solrhome/${coreName}/conf/solrcore.properties"
            then
               # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
               value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
               sed -i "s/^${valueKey}=.*/${valueKey}=${value}/" "/srv/alfresco-search-services/solrhome/${coreName}/conf/solrcore.properties"
            else
               echo "${valueKey}=${value}" >> "/srv/alfresco-search-services/solrhome/${coreName}/conf/solrcore.properties"
            fi
         fi
      fi
      if [[ $i == SHARED_* ]]
      then
         echo "Processing environment variable $i" > /proc/1/fd/1
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         value=`echo "$i" | cut -d '=' -f 2-`
         if grep --quiet "^${key}=" "/srv/alfresco-search-services/solrhome/conf/shared.properties"
         then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^${key}=.*/${key}=${value}/" "/srv/alfresco-search-services/solrhome/conf/shared.properties"
         else
            echo "${key}=${value}" >> "/srv/alfresco-search-services/solrhome/conf/shared.properties"
         fi
      fi
   done

   # always ensure ass user owns the index/config/cache
   chown -R ass:ass /srv/alfresco-search-services

   touch /var/log/alfresco-search-services/.solr-logrotate-dummy
   touch /var/lib/alfresco-search-services/.assInitDone
fi