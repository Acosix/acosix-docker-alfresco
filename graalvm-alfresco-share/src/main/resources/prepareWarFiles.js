var SUPPORTED_PACKAGINGS = ['war', 'amp', 'jar'];

function envOr(envKey, defaultValue)
{
   var value;
   
   value = $ENV[envKey];
   if ((typeof value !== 'string' && !(value instanceof String)) || value.trim() === '')
   {
      value = defaultValue;
   }
   return value;
}

function splitMultiValuedVariable(variableValue)
{
   var values, fragments;
   
   values = [];
   fragments = variableValue.split(/,/);
   fragments.forEach(function (fragment)
   {
      if(fragment.trim() !== '')
      {
         values.push(fragment.trim());
      }      
   });
   
   return values;
}

function parseArtifactCoordinates(coordinates, defaultPackaging)
{
   var descriptor, fragments;
   
   fragments = coordinates.split(/:/);
   descriptor = {
      groupId : null,
      artifactId : null,
      packaging : null,
      version : null,
      classifier : null,
      downloadedArtifactFile : null,
      
      toString : function ()
      {
         var result;

         result = (this.groupId || '?') + ':' + (this.artifactId || '?') + ':' + (this.packaging || '?');
         if (this.classifier !== null)
         {
            result += ':' + this.classifier;
         }
         result += ':' + (this.version || '?');
         
         return result;
      }
   };
   
   fragments.forEach(function (fragment)
   {
      if (fragment.trim() !== '')
      {
         if (descriptor.groupId === null)
         {
            descriptor.groupId = fragment.trim();
         }
         else if (descriptor.artifactId === null)
         {
            descriptor.artifactId = fragment.trim();
         }
         else if (descriptor.packaging === null)
         {
            descriptor.packaging = fragment.trim();
         }
         else if (descriptor.classifier === null)
         {
            descriptor.classifier = fragment.trim();
         }
         else if (descriptor.version === null)
         {
            descriptor.version = fragment.trim();
         }
      }
   });
   
   if (descriptor.classifier === null && descriptor.packaging !== null && SUPPORTED_PACKAGINGS.indexOf(descriptor.packaging) === -1)
   {
      descriptor.classifier = descriptor.packaging;
      descriptor.packaging = defaultPackaging || null;
   }

   if (descriptor.version === null && descriptor.classifier !== null)
   {
      descriptor.version = descriptor.classifier;
      descriptor.classifier = null;
   }
   
   return descriptor;
}

function parseRepositories(repositoriesStr)
{
   var repositories = splitMultiValuedVariable(repositoriesStr);
   repositories.forEach(function (repository, idx, array)
   {
      var repositoryDescriptor, key;
      repositoryDescriptor = {
         id : repository,
         baseUrl : null,
         user : null,
         password : null
      };
      
      key = 'MAVEN_REPOSITORIES_' + repositoryDescriptor.id + '_URL';
      if ((typeof $ENV[key] === 'string' || $ENV[key] instanceof String) && $ENV[key].trim() !== '')
      {
         repositoryDescriptor.baseUrl = $ENV[key].trim();
      }
      
      key = 'MAVEN_REPOSITORIES_' + repositoryDescriptor.id + '_USER';
      if ((typeof $ENV[key] === 'string' || $ENV[key] instanceof String) && $ENV[key].trim() !== '')
      {
         repositoryDescriptor.user = $ENV[key].trim();
      }
      
      key = 'MAVEN_REPOSITORIES_' + repositoryDescriptor.id + '_PASSWORD';
      if ((typeof $ENV[key] === 'string' || $ENV[key] instanceof String) && $ENV[key].trim() !== '')
      {
         repositoryDescriptor.password = $ENV[key].trim();
      }
      
      array[idx] = repositoryDescriptor;
   });
   
   return repositories;
}

function parseArtifacts(artifactsStr)
{
   var artifacts = splitMultiValuedVariable(artifactsStr);
   artifacts.forEach(function (artifact, idx, array)
   {
      array[idx] = parseArtifactCoordinates(artifact);
      array[idx].providedOrder = idx;
   });
   return artifacts;
}

function tryDownload(url, user, password)
{
   var resultFile, fileName, jUrl, con, authString, is, os, bytes, bytesRead, totalBytesRead;

   resultFile = null;
   try
   {
      jUrl = new java.net.URL(url);
      con = jUrl.openConnection();

      if (user !== null && password !== null)
      {
         authString = user + ":" + password;
         con.setRequestProperty('Authorization', 'Basic ' + java.util.Base64.getEncoder().encodeToString(authString.bytes));
      }
      
      con.setRequestMethod("GET");
      con.setAllowUserInteraction(false);
      con.setDoInput(true);
      con.setDoOutput(false);
      
      
      fileName = url.substring(url.lastIndexOf('/') + 1);
      resultFile = $ARG.length > 0 ? new java.io.File(new java.io.File($ARG[0]), fileName) : new java.io.File(fileName);
      
      if (!resultFile.exists() || resultFile.length() === 0 || envOr('MAVEN_OVERRIDE_EXISTING_FILES', 'false') === 'true')
      {
         is = con.inputStream;
         os = new java.io.FileOutputStream(resultFile, false);
         
         bytes = new Array(8192);
         bytes = Java.to(bytes, 'byte[]');
         totalBytesRead = 0;
         
         while ((bytesRead = is.read(bytes)) !== -1)
         {
            os.write(bytes, 0, bytesRead);
            
            totalBytesRead += bytesRead;
            // log every ~5 MiB
            if (totalBytesRead % (5 * 128 * 8192) < 8192)
            {
               print('Download of ' + fileName + ' in progress - ' + totalBytesRead + ' bytes transferred');
            }
         }
         
         os.close();
         is.close();
         
         print('Download of ' + fileName + ' completed - ' + totalBytesRead + ' bytes transferred');
      }
      else
      {
         print('File ' + fileName + ' already exists locally and override has not been requested via maven.overrideExistingFiles');
      }
   }
   catch (e)
   {
      if (resultFile !== null && resultFile.exists())
      {
         resultFile.delete();
      }
      
      if (os !== undefined && os !== null)
      {
         os.close();
      }
      
      if (is !== undefined && is !== null)
      {
         is.close();
      }
      
      if (!(e instanceof java.io.FileNotFoundException))
      {
         print('Error during download: ' + e.message);
      }
   }
   return resultFile;
}

function determineSnapshotVersion(baseUrl, repositoryDescriptor)
{
   var metadataFile, metadata, matches, timestamp, buildNumber, snapshotVersion, metadataAltFile;

   try
   {
      metadataFile = tryDownload(baseUrl + 'maven-metadata.xml', repositoryDescriptor.user, repositoryDescriptor.password);
      metadata = readFully(metadataFile.path);

      matches = /<timestamp>([^<]+)<\/timestamp>/.exec(metadata);
      if (matches)
      {
         timestamp = matches[1];

         matches = /<buildNumber>([^<]+)<\/buildNumber>/.exec(metadata);
         if (matches)
         {
            buildNumber = matches[1];
            snapshotVersion = timestamp + '-' + buildNumber;
         }
      }

      if (!metadataFile.delete())
      {
         print('maven-metadata.xml could not be cleaned up - renaming to avoid re-use for other snapshot version determinations');

         metadataAltFile = new java.io.File(metadataFile.parent, java.util.UUID.randomUUID().toString() + '.xml');
         metadataFile.renameTo(metadataAltFile);
         metadataAltFile.deleteOnExit();
      }
   }
   catch(e)
   {
      if (metadataFile !== undefined)
      {
         if (!metadataFile.delete())
         {
            print('maven-metadata.xml could not be cleaned up - renaming to avoid re-use for other snapshot version determinations');

            metadataAltFile = new java.io.File(metadataFile.parent, java.util.UUID.randomUUID().toString() + '.xml');
            metadataFile.renameTo(metadataAltFile);
            metadataAltFile.deleteOnExit();
         }
      }
   }
   return snapshotVersion;
}

function downloadArtifact(artifactDescriptor, repositoryDescriptors)
{
   repositoryDescriptors.forEach(function (repositoryDescriptor)
   {
      var expectedUrl, snapshotVersion;

      if (artifactDescriptor.downloadedArtifactFile === null || !artifactDescriptor.downloadedArtifactFile.exists())
      {
         if (repositoryDescriptor.baseUrl !== null)
         {
            print('Attempting to download ' + artifactDescriptor + ' from ' + repositoryDescriptor.id);

            expectedUrl = repositoryDescriptor.baseUrl;
            if (!expectedUrl.endsWith('/'))
            {
               expectedUrl += '/';
            }
            expectedUrl += artifactDescriptor.groupId.split(/\./).join('/');
            expectedUrl += '/';
            expectedUrl += artifactDescriptor.artifactId;
            expectedUrl += '/';
            expectedUrl += artifactDescriptor.version;
            expectedUrl += '/';

            if (/-SNAPSHOT$/.test(artifactDescriptor.version))
            {
               snapshotVersion = determineSnapshotVersion(expectedUrl, repositoryDescriptor);

               print('Artifact defines SNAPSHOT-version - determined timestamp-based snapshot version ' + snapshotVersion + ' for download from ' + repositoryDescriptor.id);
            }

            expectedUrl += artifactDescriptor.artifactId;
            expectedUrl += '-';

            if (snapshotVersion !== undefined)
            {
               expectedUrl += artifactDescriptor.version.replace(/SNAPSHOT$/, snapshotVersion);
            }
            else
            {
               expectedUrl += artifactDescriptor.version;
            }

            if (artifactDescriptor.classifier !== null)
            {
               expectedUrl +='-';
               expectedUrl += artifactDescriptor.classifier;
            }

            if (artifactDescriptor.packaging !== null)
            {
               expectedUrl += '.';
               expectedUrl += artifactDescriptor.packaging;

               print('Artifact defines explicit packaging - using URL ' + expectedUrl + ' for download attempt');

               artifactDescriptor.downloadedArtifactFile = tryDownload(expectedUrl, repositoryDescriptor.user, repositoryDescriptor.password);
            }
            else
            {
               print('Artifact does not define explicit packaging - trying to find first available packaging from supported formats ' + JSON.stringify(SUPPORTED_PACKAGINGS));
               SUPPORTED_PACKAGINGS.forEach(function(packaging)
               {
                  var url;
                  if (artifactDescriptor.downloadedArtifactFile === null || !artifactDescriptor.downloadedArtifactFile.exists())
                  {
                     url = expectedUrl + '.' + packaging;
                     print('Using URL ' + url + ' for download attempt');
                     artifactDescriptor.downloadedArtifactFile = tryDownload(url, repositoryDescriptor.user, repositoryDescriptor.password);
                  }
               });
            }

            if (artifactDescriptor.downloadedArtifactFile !== null && artifactDescriptor.downloadedArtifactFile.exists())
            {
               print('Successfully downloaded ' + artifactDescriptor + ' from ' + repositoryDescriptor.id);
            }
            else
            {
               print('Artifact ' + artifactDescriptor + ' not found on ' + repositoryDescriptor.id);;
            }
         }
      }
   });
}

function downloadArtifacts(artifactDsscriptors, repositoryDescriptors)
{
   artifactDsscriptors.forEach(function(artifactDescriptor)
   {
      if (artifactDescriptor.groupId !== null && artifactDescriptor.artifactId !== null && artifactDescriptor.version !== null)
      {
         print('Attempting to download ' + artifactDescriptor);
         downloadArtifact(artifactDescriptor, repositoryDescriptors);
      }
      else
      {
         throw new Error('Incomplete artifact descriptor: ' + JSON.stringify(artifactDescriptor));
      }
      
      if (artifactDescriptor.downloadedArtifactFile === null || !artifactDescriptor.downloadedArtifactFile.exists())
      {
         throw new Error(String(artifactDescriptor) + ' not found in any of the configured repositories');
      }
   });
}

function installArtifacts(platformWar, mmtJar, artifactsToInstall)
{
   artifactsToInstall.forEach(function (artifact)
   {
      var cmdLine, processBuilder, process, uri, zipFs;
      if (artifact.packaging === 'amp' || artifact.downloadedArtifactFile.name.endsWith('.amp'))
      {
         cmdLine = '';
         if (java.lang.System.getProperty('os.name').toLowerCase(java.util.Locale.ENGLISH).indexOf('windows') !== -1)
         {
            cmdLine = 'cmd /c ';
         }
         cmdLine += 'java -jar ' + mmtJar.downloadedArtifactFile.canonicalPath + ' install ' + artifact.downloadedArtifactFile.canonicalPath + ' ' + platformWar.downloadedArtifactFile.canonicalPath;
         processBuilder = new java.lang.ProcessBuilder(cmdLine.split(/\s/));
         processBuilder.inheritIO();
         process = processBuilder.start();
         
         if (process.waitFor() !== 0)
         {
            throw new Error('Failed to install ' + artifact);
         }
      }
   });
}

function main()
{
   var alfrescoVersions, alfrescoArtifacts, repositories, artifacts, requiredAlfrescoArtifacts;
   
   alfrescoVersions = {
      mmt : envOr('ALFRESCO_MMT_VERSION', '6.0'),
      share : envOr('ALFRESCO_SHARE_VERSION', '6.0.c')
   };
   
   alfrescoArtifacts = {
      mmtJar : parseArtifactCoordinates('org.alfresco:alfresco-mmt:jar:' + alfrescoVersions.mmt),
      shareWar : parseArtifactCoordinates(envOr('SHARE_WAR_ARTIFACT', 'org.alfresco:share:war:' + alfrescoVersions.share))
   };
   
   repositories = parseRepositories(envOr('MAVEN_ACTIVE_REPOSITORIES', 'alfresco,alfresco_ee,central'));
   artifacts = parseArtifacts(envOr('MAVEN_REQUIRED_ARTIFACTS', ''));
   
   requiredAlfrescoArtifacts = [alfrescoArtifacts.mmtJar, alfrescoArtifacts.shareWar];
   
   downloadArtifacts(requiredAlfrescoArtifacts, repositories);
   downloadArtifacts(artifacts, repositories);
   
   installArtifacts(alfrescoArtifacts.shareWar, alfrescoArtifacts.mmtJar, artifacts);
   
   if (alfrescoArtifacts.shareWar.downloadedArtifactFile.name !== 'share.war')
   {
      alfrescoArtifacts.shareWar.downloadedArtifactFile.renameTo(new java.io.File(alfrescoArtifacts.shareWar.downloadedArtifactFile.parent, 'share.war'));
   }

   alfrescoArtifacts.mmtJar.downloadedArtifactFile.delete();
}

main();