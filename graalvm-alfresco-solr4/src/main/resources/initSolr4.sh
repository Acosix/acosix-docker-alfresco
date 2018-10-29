#!/bin/bash

set -e

ENABLED_CORES=${ENABLED_CORES:=alfresco,archive}

SOLR_HOST=${SOLR_HOST:=localhost}
SOLR_PORT=${SOLR_PORT:=8983}

REPOSITORY_HOST=${REPOSITORY_HOST:=localhost}
REPOSITORY_PORT=${REPOSITORY_PORT:=80}

ACCESS_REPOSITORY_VIA_SSL=${ACCESS_REPOSITORY_VIA_SSL:=false}
REPOSITORY_SSL_PORT=${REPOSITORY_SSL_PORT:=443}

PROXY_NAME=${PROXY_NAME:=localhost}
PROXY_NAME_RAW=${PROXY_NAME_RAW:-$PROXY_NAME}
PROXY_PORT_RAW=${PROXY_PORT_RAW:=8082}
PROXY_SSL_PORT_RAW=${PROXY_SSL_PORT_RAW:=8083}

INIT_KEYSTORE_FROM_DEFAULT=${INIT_KEYSTORE_FROM_DEFAULT:=true}

IFS=',' read -ra CORE_LIST <<< "$ENABLED_CORES"

if [ ! -d '/srv/alfresco-solr4/solrhome' ]
then
   if [ -f '/var/lib/tomcat8/prepareSolr4Files.js' ]
   then
      if [[ -d '/srv/alfresco-solr4/defaultArtifacts' ]]
      then
         echo "Using default artifacts: $(ls -A /srv/alfresco-solr4/defaultArtifacts)"
         # in case folder is empty we have to suppress error code
         cp /srv/alfresco-solr4/defaultArtifacts/* /tmp/ 2>/dev/null || :
      fi
      echo "Preparing SOLR 4 WAR and directories"
      jjs -scripting /var/lib/tomcat8/prepareSolr4Files.js -- /tmp

      mkdir -p /srv/alfresco-solr4/solrhome
      unzip -qq "/tmp/config.zip" -d /srv/alfresco-solr4/solrhome/

      if [[ ! -z "$(ls -A /tmp/*.jar)" ]]
      then
         mv /tmp/*.jar /srv/alfresco-solr4/modules/
      fi

      mkdir -p /etc/tomcat8/Catalina/localhost
      mv /srv/alfresco-solr4/solrhome/context.xml /etc/tomcat8/Catalina/localhost/solr4.xml
      sed -i 's/@@ALFRESCO_SOLR4_DIR@@/\/srv\/alfresco-solr4\/solrhome/' /etc/tomcat8/Catalina/localhost/solr4.xml
      sed -i 's/@@ALFRESCO_SOLR4_MODEL_DIR@@/\/srv\/alfresco-solr4\/index\/_models/' /etc/tomcat8/Catalina/localhost/solr4.xml
      sed -i 's/@@ALFRESCO_SOLR4_CONTENT_DIR@@/\/srv\/alfresco-solr4\/index\/_content/' /etc/tomcat8/Catalina/localhost/solr4.xml
      sed -i '/<\/Context>/i <Resources>' /etc/tomcat8/Catalina/localhost/solr4.xml
      sed -i '/<\/Context>/i <PostResources base="/srv/alfresco-solr4/modules" className="org.apache.catalina.webresources.DirResourceSet" webAppMount="/WEB-INF/lib" />' /etc/tomcat8/Catalina/localhost/solr4.xml
      sed -i '/<\/Context>/i </Resources>' /etc/tomcat8/Catalina/localhost/solr4.xml
      sed -i 's/rootLogger=ERROR, file, CONSOLE/rootLogger=ERROR, file/' /srv/alfresco-solr4/solrhome/log4j-solr.properties
      sed -i 's/File=solr\.log/File=\${catalina.base}\/logs\/solr.log/' /srv/alfresco-solr4/solrhome/log4j-solr.properties

      if [[ -z "$(ls -A /srv/alfresco-solr4/solrhome/templates/rerank)" && -z "$(ls -A /srv/alfresco-solr4/solrhome/templates/vanilla)" ]]
      then
         # old SOLR 4 version may not provide any templates
         echo "SOLR 4 version does not provide usable core templates - using default workspace-SpacesStore config as vanilla template"
         mv /srv/alfresco-solr4/solrhome/workspace-SpacesStore /srv/alfresco-solr4/solrhome/templates/vanilla
         rm /srv/alfresco-solr4/solrhome/templates/vanilla/core.properties
      fi

      rm -rf /srv/alfresco-solr4/solrhome/workspace-SpacesStore /srv/alfresco-solr4/solrhome/archive-SpacesStore

      mkdir -p /srv/alfresco-solr4/index/_content
      mkdir -p /srv/alfresco-solr4/index/_models
      chown -R tomcat8:tomcat8 /srv/alfresco-solr4/solrhome
      chown -R tomcat8:tomcat8 /srv/alfresco-solr4/index

      mv /tmp/*.war /var/lib/tomcat8/webapps/

      rm -f /tmp/*.zip /tmp/*.war*
   fi
fi

if [ ! -f '/var/lib/tomcat8/.solr4InitDone' ]
then
   if [[ $INIT_KEYSTORE_FROM_DEFAULT == true && -z "$(ls -A /srv/alfresco-solr4/keystore)" ]]
   then
      echo "Initialising keystore from default"
      cp /srv/alfresco-solr4/defaultKeystore/* /srv/alfresco-solr4/keystore/ 2>/dev/null || :
      chown tomcat8:tomcat8 /srv/alfresco-solr4/keystore/*
   fi

   echo "Setting up raw HTTP connector"
   sed -i '/<Engine/i <Connector executor="tomcatThreadPool" port="8082" protocol="HTTP/1.1"' /etc/tomcat8/server.xml
   sed -i '/<Engine/i connectionTimeout="20000" redirectPort="%PROXY_SSL_PORT_RAW%" URIEncoding="UTF-8" maxHttpHeaderSize="32768"' /etc/tomcat8/server.xml
   sed -i '/<Engine/i proxyName="%PROXY_NAME_RAW%" proxyPort="%PROXY_PORT_RAW%" />' /etc/tomcat8/server.xml

   if [[ -f '/srv/alfresco-solr4/keystore/ssl.keystore' && -f '/srv/alfresco-solr4/keystore/ssl-keystore-passwords.properties' && -f '/srv/alfresco-solr4/keystore/ssl.truststore' && -f '/srv/alfresco-solr4/keystore/ssl-truststore-passwords.properties' ]]
   then
      echo "Setting up raw SSL connector and Tomcat users"

      SSL_KEYSTORE_PASSWORD=$(grep 'keystore.password=' /srv/alfresco-solr4/keystore/ssl-keystore-passwords.properties | sed -r 's/keystore\.password=(.+)/\1/')
      SSL_TRUSTSTORE_PASSWORD=$(grep 'keystore.password=' /srv/alfresco-solr4/keystore/ssl-truststore-passwords.properties | sed -r 's/keystore\.password=(.+)/\1/')

      sed -i '/<Engine/i <Connector executor="tomcatThreadPool" port="8083" protocol="org.apache.coyote.http11.Http11Protocol" SSLEnabled="true"' /etc/tomcat8/server.xml
      sed -i '/<Engine/i proxyName="%PROXY_NAME_RAW%" proxyPort="%PROXY_SSL_PORT_RAW%"' /etc/tomcat8/server.xml
      sed -i '/<Engine/i scheme="https" secure="true"' /etc/tomcat8/server.xml
      sed -i '/<Engine/i keystoreFile="/srv/alfresco-solr4/keystore/ssl.keystore" keystorePass="%SSL_KEYSTORE_PASSWORD%" keystoreType="JCEKS"' /etc/tomcat8/server.xml
      sed -i '/<Engine/i truststoreFile="/srv/alfresco-solr4/keystore/ssl.truststore" truststorePass="%SSL_TRUSTSTORE_PASSWORD%" truststoreType="JCEKS"' /etc/tomcat8/server.xml
      sed -i '/<Engine/i clientAuth="want" sslProtocol="TLS" connectionTimeout="240000"' /etc/tomcat8/server.xml
      sed -i '/<Engine/i URIEncoding="UTF-8" maxHttpHeaderSize="32768" allowUnsafeLegacyRenegotiation="true" />' /etc/tomcat8/server.xml
      sed -i "s/%SSL_KEYSTORE_PASSWORD%/${SSL_KEYSTORE_PASSWORD}/" /etc/tomcat8/server.xml
      sed -i "s/%SSL_TRUSTSTORE_PASSWORD%/${SSL_TRUSTSTORE_PASSWORD}/" /etc/tomcat8/server.xml

      sed -i '/<\/tomcat-users>/i <user username="CN=Alfresco Repository, OU=Unknown, O=Alfresco Software Ltd., L=Maidenhead, ST=UK, C=GB" roles="repository" password="null" />' /etc/tomcat8/tomcat-users.xml
   fi

   sed -i "s/%PROXY_NAME_RAW%/${PROXY_NAME_RAW}/" /etc/tomcat8/server.xml
   sed -i "s/%PROXY_PORT_RAW%/${PROXY_PORT_RAW}/" /etc/tomcat8/server.xml
   sed -i "s/%PROXY_SSL_PORT_RAW%/${PROXY_SSL_PORT_RAW}/" /etc/tomcat8/server.xml

   CUSTOM_APPENDER_LIST='';

   # otherwise for will also cut on whitespace
   IFS=$'\n'
   for i in `env`
   do
      value=`echo "$i" | cut -d '=' -f 2-`
      if [[ $i == LOG4J-APPENDER_* ]]
      then
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         appenderName=`echo $key | cut -d '.' -f 1`
         if grep --quiet "^${key}=" /srv/alfresco-solr4/solrhome/log4j-solr.properties; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^log4j\.appender\.${key}=.*/log4j.appender.${key}=${value}/" /srv/alfresco-solr4/solrhome/log4j-solr.properties
         else
            echo "log4j.appender.${key}=${value}" >> /srv/alfresco-solr4/solrhome/log4j-solr.properties
         fi

         if [[ ! $CUSTOM_APPENDER_LIST =~ "^,([^,]+,)*${appenderName}(,[^,$]+)*$" ]]
         then
            CUSTOM_APPENDER_LIST="${CUSTOM_APPENDER_LIST},${appenderName}"
         fi
      elif [[ $i == LOG4J-LOGGER_* ]]
      then
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         if grep --quiet "^${key}=" /srv/alfresco-solr4/solrhome/log4j-solr.properties; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^log4j\.logger\.${key}=.*/log4j.logger.${key}=${value}/" /srv/alfresco-solr4/solrhome/log4j-solr.properties
         else
            echo "log4j.logger.${key}=${value}" >> /srv/alfresco-solr4/solrhome/log4j-solr.properties
         fi
      elif [[ $i == LOG4J-ADDITIVITY_* ]]
      then
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         if grep --quiet "^${key}=" /srv/alfresco-solr4/solrhome/log4j-solr.properties; then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
            sed -i "s/^log4j\.additivity\.${key}=.*/log4j.additivity.${key}=${value}/" /srv/alfresco-solr4/solrhome/log4j-solr.properties
         else
            echo "log4j.additivity.${key}=${value}" >> /srv/alfresco-solr4/solrhome/log4j-solr.properties
         fi
      fi
   done
   sed -i 's/rootLogger=ERROR, file/rootLogger=ERROR, file, ${CUSTOM_APPENDER_LIST}/' /srv/alfresco-solr4/solrhome/log4j-solr.properties


   NEW_CORE_LIST=''
   for core in "${CORE_LIST[@]}"
   do
      if [[ ! -d "/srv/alfresco-solr4/coreConfigs/${core}" || ! -f "/srv/alfresco-solr4/coreConfigs/${core}/core.properties" ]]
      then
         echo "Setting up SOLR 4 core ${core}"
         
         if [[ -z "$(ls -A /srv/alfresco-solr4/solrhome/templates/rerank)" ]]
         then
            cp -r /srv/alfresco-solr4/solrhome/templates/vanilla "/srv/alfresco-solr4/coreConfigs/${core}"
         else
            cp -r /srv/alfresco-solr4/solrhome/templates/rerank "/srv/alfresco-solr4/coreConfigs/${core}"
         fi
         echo "name=${core}" >> "/srv/alfresco-solr4/coreConfigs/${core}/core.properties"
         ln -s "/srv/alfresco-solr4/coreConfigs/${core}" "/srv/alfresco-solr4/solrhome/${core}"

         sed -i "s/data\.dir\.root=.*/data.dir.root=\/srv\/alfresco-solr4\/index/" "/srv/alfresco-solr4/solrhome/${core}/conf/solrcore.properties"
         sed -i "s/data\.dir\.store=.*/data.dir.store=${core}/" "/srv/alfresco-solr4/solrhome/${core}/conf/solrcore.properties"
         sed -i "s/host=.*/host=${REPOSITORY_HOST}/" "/srv/alfresco-solr4/solrhome/${core}/conf/solrcore.properties"
         sed -i "s/port=.*/port=${REPOSITORY_PORT}/" "/srv/alfresco-solr4/solrhome/${core}/conf/solrcore.properties"
         sed -i "s/port\.ssl=.*/port.ssl=${REPOSITORY_SSL_PORT}/" "/srv/alfresco-solr4/solrhome/${core}/conf/solrcore.properties"

         if [[ $ACCESS_REPOSITORY_VIA_SSL == true ]]
         then
            sed -i "s/secureComms=.*/secureComms=https/" "/srv/alfresco-solr4/solrhome/${core}/conf/solrcore.properties"
         else
            sed -i "s/secureComms=.*/secureComms=none/" "/srv/alfresco-solr4/solrhome/${core}/conf/solrcore.properties"
         fi

         if [[ ${core} == 'alfresco' ]]
         then
            sed -i "s/alfresco\.stores=.*/alfresco.stores=workspace:\/\/SpacesStore/" "/srv/alfresco-solr4/solrhome/${core}/conf/solrcore.properties"
         fi
         if [[ ${core} == 'archive' ]]
         then
            sed -i "s/alfresco\.stores=.*/alfresco.stores=archive:\/\/SpacesStore/" "/srv/alfresco-solr4/solrhome/${core}/conf/solrcore.properties"
         fi

         if [[ $NEW_CORE_LIST ]]
         then
            NEW_CORE_LIST="${NEW_CORE_LIST},${core}"
         else
            NEW_CORE_LIST=${core}
         fi
      elif [[ ! -d "/srv/alfresco-solr4/solrhome/${core}" ]]
      then
         echo "Linking existing SOLR 4 core ${core}"
         ln -s "/srv/alfresco-solr4/coreConfigs/${core}" "/srv/alfresco-solr4/solrhome/${core}"
      fi
   done

   for i in `env`
   do
        if [[ $i == CORE_* ]]
      then
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         coreName=`echo $key | cut -d '.' -f 1`
         valueKey=`echo $key | cut -d '.' -f 2-`
         value=`echo "$i" | cut -d '=' -f 2-`

         # we only apply settings for core configs we created in this run
         if [[ $NEW_CORE_LIST =~ "^([^,]+,)*${coreName}(,[^,$]+)*$" ]]
         then
            if grep --quiet "^${key}=" "/srv/alfresco-solr4/solrhome/${coreName}/conf/solrcore.properties"
            then
               # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
               value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
               sed -i "s/^${valueKey}=.*/${valueKey}=${value}/" "/srv/alfresco-solr4/solrhome/${coreName}/conf/solrcore.properties"
            else
               echo "${valueKey}=${value}" >> "/srv/alfresco-solr4/solrhome/${coreName}/conf/solrcore.properties"
            fi
         fi
      fi
      if [[ $i == SHARED_* ]]
      then
         key=`echo "$i" | cut -d '=' -f 1 | cut -d '_' -f 2-`
         value=`echo "$i" | cut -d '=' -f 2-`
         if grep --quiet "^${key}=" "/srv/alfresco-solr4/solrhome/conf/shared.properties"
         then
            # encode any / in $value to avoid interference with sed (note: sh collapses 2 \'s into 1)
            value=`echo "$value" | sed -r 's/\\//\\\\\//g'`
         else
            echo "${key}=${value}" >> "/srv/alfresco-solr4/solrhome/conf/shared.properties"
         fi
      fi
   done
   
   touch /var/lib/tomcat8/.solr4InitDone
fi