/var/log/tomcat8/.solr4-logrotate-dummy {
   su tomcat8 tomcat8
   rotate 0
   daily
   ifempty
   missingok
   create 640 tomcat8 tomcat8
   lastaction
      /usr/bin/find /var/lib/tomcat8/logs/solr.log.*.gz -daystart -mtime +26 -delete
      /usr/bin/find /var/lib/tomcat8/logs/solr.log.????-??-?? -daystart -mtime +1 -exec gzip -q '{}' \;
   endscript
}