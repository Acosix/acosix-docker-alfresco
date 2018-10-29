/var/log/tomcat7/.share-logrotate-dummy {
   su tomcat7 tomcat7
   rotate 0
   daily
   ifempty
   missingok
   create 640 tomcat7 tomcat7
   lastaction
      /usr/bin/find /var/lib/tomcat7/logs/share.log.*.gz -daystart -mtime +26 -delete
      /usr/bin/find /var/lib/tomcat7/logs/share.log.????-??-?? -daystart -mtime +1 -exec gzip -q '{}' \;
   endscript
}