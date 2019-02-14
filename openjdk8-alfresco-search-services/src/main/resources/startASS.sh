#!/bin/bash

set -e

REPOSITORY_HOST=${REPOSITORY_HOST:=localhost}
REPOSITORY_PORT=${REPOSITORY_PORT:=80}
ACCESS_REPOSITORY_VIA_SSL=${ACCESS_REPOSITORY_VIA_SSL:=false}
REPOSITORY_SSL_PORT=${REPOSITORY_SSL_PORT:=443}

url=""
if [[ $ACCESS_REPOSITORY_VIA_SSL == true ]]
then
    url="https://$REPOSITORY_HOST:$REPOSITORY_SSL_PORT/alfresco"
else
    url="http://$REPOSITORY_HOST:$REPOSITORY_PORT/alfresco"
fi

until curl -s "$url"; do
  >&2 echo "Repository is unavailable - sleeping"
  sleep 1
done

exec /sbin/setuser ass /var/lib/alfresco-search-services/solr/bin/solr start -f >> /var/log/alfresco-search-services/solr.out 2>&1