/var/log/alfresco-search-services/solr.out {
   su solr solr
   copytruncate
   daily
   rotate 28
   dateext
   compress
   missingok
   create 640 solr solr
}

/var/log/alfresco-search-services/.solr-logrotate-dummy {
   su solr solr
   rotate 0
   daily
   ifempty
   missingok
   create 640 solr solr
   lastaction
      /usr/bin/find /var/log/alfresco-search-services/solr.log.*.gz -daystart -mtime +26 -delete
      /usr/bin/find /var/log/alfresco-search-services/solr.log.????-??-?? -daystart -mtime +1 -exec gzip -q '{}' \;
   endscript
}